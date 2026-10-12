"""Persistent phase state and deterministic quality gates (Python 3.11+)."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import tempfile
from contextlib import AbstractContextManager
from datetime import datetime, timezone
from pathlib import Path

STATUSES = {"backlog", "ready", "in_progress", "testing", "review", "blocked", "done"}
ROLES = {"tech_lead", "architect", "backend_developer", "flutter_flame_developer", "qa_engineer", "code_reviewer"}
BOARD = "docs/development/task-board.json"
PROGRESS = "docs/development/progress.md"
TRANSITIONS = {
    "backlog": {"ready", "blocked"}, "ready": {"in_progress", "blocked"},
    "in_progress": {"testing", "blocked"}, "testing": {"review", "in_progress", "blocked"},
    "review": {"in_progress", "blocked"}, "blocked": {"backlog", "ready"}, "done": set(),
}


class GateError(ValueError):
    pass


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def slug(value: str) -> str:
    value = value.lower().strip()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", value):
        raise GateError("Phase must be a short name containing letters, digits, _ or -")
    return value


def local(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value:
        raise GateError("Expected a non-empty workspace-relative path")
    candidate = (root / value).resolve()
    if not candidate.is_relative_to(root.resolve()) or Path(value).is_absolute():
        raise GateError(f"Path must remain inside the workspace: {value}")
    return candidate


def digest(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, name = tempfile.mkstemp(prefix=".checkpoint-", dir=path.parent)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


class WorkspaceLock(AbstractContextManager):
    """OS-held lock; process exit releases it without unsafe stale-lock deletion."""
    def __init__(self, root: Path):
        self.path = root / ".autonomy/runner.lock"
        self.stream = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.stream = self.path.open("a+b")
        self.stream.seek(0, os.SEEK_END)
        if self.stream.tell() == 0:
            self.stream.write(b"0")
            self.stream.flush()
        self.stream.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.stream.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            self.stream.close()
            self.stream = None
            raise GateError("Another supervised run owns this workspace") from error
        return self

    def __exit__(self, *args):
        if self.stream:
            self.stream.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.stream, fcntl.LOCK_UN)
            self.stream.close()


def read_board(root: Path) -> dict:
    path = root / BOARD
    board = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"schema_version": 1, "phases": {}}
    if board.get("schema_version") != 1 or not isinstance(board.get("phases"), dict):
        raise GateError("Unsupported or malformed task board")
    return board


def phase_of(board: dict, name: str) -> dict:
    name = slug(name)
    if name not in board["phases"]:
        raise GateError(f"Unknown phase {name}; initialize it first")
    return board["phases"][name]


def persist(root: Path, board: dict) -> None:
    board["updated_at"] = now()
    atomic_json(root / BOARD, board)
    lines = ["# Phase progress", "", f"Updated: {board['updated_at']} (UTC)", ""]
    for name, phase in board["phases"].items():
        counts = {state: sum(t["status"] == state for t in phase["tasks"]) for state in sorted(STATUSES)}
        lines += [f"## {name}", "", f"Scope: `{phase['scope_path']}`; approval: **{phase['approval']['status']}**.",
                  f"Execution: **{phase.get('execution_status', 'not_started')}**.",
                  ", ".join(f"{state}: {count}" for state, count in counts.items()), ""]
        for task in phase["tasks"]:
            lines.append(f"- {task['id']} [{task['status']}] {task['description']} (attempts: {task['retry_count']})")
            if task.get("blocker"):
                lines.append(f"  Blocker: {task['blocker']}")
        lines += ["", f"Last checkpoint: {phase.get('last_message', 'No execution yet.')}", ""]
    (root / PROGRESS).parent.mkdir(parents=True, exist_ok=True)
    (root / PROGRESS).write_text("\n".join(lines), encoding="utf-8")


def initialize(root: Path, name: str, scope: str) -> dict:
    board = read_board(root)
    name = slug(name)
    local(root, scope)
    if name in board["phases"]:
        raise GateError(f"Phase {name} already exists; initialization never overwrites it")
    board["phases"][name] = {
        "scope_path": scope, "approval": {"status": "pending", "scope_sha256": None,
        "contract_sha256": None, "approved_by": None, "approved_at": None, "development_branch": None},
        "contract": {"requirements": [], "checks": {}, "required_phase_checks": []},
        "tasks": [], "execution_status": "awaiting_approval", "last_message": "Scope requires user approval.",
    }
    persist(root, board)
    return board


def validate_contract(contract: dict) -> None:
    requirements = contract.get("requirements")
    checks = contract.get("checks")
    required = contract.get("required_phase_checks")
    if not isinstance(requirements, list) or not requirements or not all(isinstance(x, str) and x for x in requirements):
        raise GateError("Approved contract needs non-empty requirement IDs")
    if len(set(requirements)) != len(requirements):
        raise GateError("Duplicate requirement ID")
    if not isinstance(checks, dict) or not checks:
        raise GateError("Approved contract needs check IDs and argv commands")
    for key, argv in checks.items():
        if not key or not isinstance(argv, list) or not argv or not all(isinstance(x, str) and x for x in argv):
            raise GateError(f"Invalid check command: {key}")
    if not isinstance(required, list) or not required or not all(isinstance(x, str) and x in checks for x in required):
        raise GateError("Required phase checks must reference approved check IDs")


def approve(root: Path, board: dict, name: str, branch: str, approver: str, contract: dict) -> None:
    phase = phase_of(board, name)
    validate_contract(contract)
    if not branch or branch in {"main", "master"} or not approver.strip():
        raise GateError("Specify a non-protected development branch and external approval reference")
    if phase["approval"]["status"] == "approved":
        raise GateError("Approval already recorded; scope/contract revisions need a new phase or explicit approval revision")
    scope = local(root, phase["scope_path"])
    if not scope.is_file():
        raise GateError("Write and approve the phase scope before recording approval")
    phase["contract"] = contract
    phase["approval"] = {"status": "approved", "scope_sha256": file_digest(scope),
        "contract_sha256": digest(contract), "development_branch": branch,
        "approved_by": approver, "approved_at": now()}
    phase["execution_status"] = "not_started"
    phase["last_message"] = "Scope approval recorded; execution still requires an explicit phase command."
    persist(root, board)


def check_approval(root: Path, phase: dict) -> None:
    approval = phase["approval"]
    if approval.get("status") != "approved":
        raise GateError("Phase scope is not approved; propose scope and request user approval")
    validate_contract(phase["contract"])
    if file_digest(local(root, phase["scope_path"])) != approval["scope_sha256"]:
        raise GateError("Scope changed after approval")
    if digest(phase["contract"]) != approval["contract_sha256"]:
        raise GateError("Requirements/check contract changed after approval")


def validate_tasks(phase: dict) -> None:
    tasks = phase["tasks"]
    ids = [t.get("id") for t in tasks]
    if any(not isinstance(x, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", x) for x in ids) or len(set(ids)) != len(ids):
        raise GateError("Task IDs must be unique safe identifiers")
    for task in tasks:
        for field in ("description", "epic", "feature"):
            if not isinstance(task.get(field), str) or not task[field].strip():
                raise GateError(f"{task['id']}: missing {field}")
        if task.get("assigned_agent") not in ROLES or task.get("status") not in STATUSES:
            raise GateError(f"{task['id']}: invalid role/status")
        if type(task.get("priority")) is not int or not 0 <= task["priority"] <= 3:
            raise GateError("Priority must be 0 (highest) through 3")
        if type(task.get("retry_count")) is not int or task["retry_count"] < 0:
            raise GateError("retry_count must be a non-negative integer")
        for field in ("dependencies", "acceptance_criteria", "relevant_files", "test_requirements", "requirements", "subtasks"):
            if not isinstance(task.get(field), list) or not all(isinstance(x, str) for x in task[field]):
                raise GateError(f"{task['id']}: {field} must be a string list")
        if not task["acceptance_criteria"] or not task["test_requirements"] or not task["requirements"]:
            raise GateError(f"{task['id']}: acceptance, tests, and requirement mapping are required")
        if any(d not in ids or d == task["id"] for d in task["dependencies"]):
            raise GateError("Missing/self dependency")
        if any(r not in phase["contract"]["requirements"] for r in task["requirements"]):
            raise GateError("Task references an unapproved requirement")
        if any(c not in phase["contract"]["checks"] for c in task["test_requirements"]):
            raise GateError("Task references an unapproved check")
    edges = {t["id"]: t["dependencies"] for t in tasks}
    visited, active = set(), set()
    def visit(task_id):
        if task_id in active:
            raise GateError("Task dependencies contain a cycle")
        if task_id not in visited:
            active.add(task_id)
            for child in edges[task_id]:
                visit(child)
            active.remove(task_id)
            visited.add(task_id)
    for task_id in ids:
        visit(task_id)


def upsert_task(root: Path, board: dict, name: str, task: dict) -> None:
    phase = phase_of(board, name)
    check_approval(root, phase)
    old = next((t for t in phase["tasks"] if t["id"] == task.get("id")), None)
    if task.get("status") == "done":
        raise GateError("Only supervisor verification may mark a task done")
    if old:
        if old["status"] == "done" or (old["status"] != task["status"] and task["status"] not in TRANSITIONS[old["status"]]):
            raise GateError("Illegal task transition; reopen via a linked defect task")
        if task["retry_count"] < old["retry_count"]:
            raise GateError("Retry count cannot decrease")
        if old.get("needs_different_diagnosis") and task["status"] in {"ready", "in_progress", "testing", "review"}:
            report = json.loads(local(root, task.get("diagnosis_report", "")).read_text(encoding="utf-8"))
            if (report.get("kind") != "diagnosis" or report.get("task_id") != task["id"]
                or report.get("role") not in ROLES or report["role"] == task["assigned_agent"]
                or report.get("retry_count") != old["retry_count"] or not report.get("new_approach")):
                raise GateError("Three failed attempts require a different specialist diagnosis and new approach")
            task["needs_different_diagnosis"] = False
    elif task.get("status") != "backlog":
        raise GateError("New tasks start in backlog")
    replacement = [task if t["id"] == task["id"] else t for t in phase["tasks"]]
    if old is None:
        replacement.append(task)
    trial = {**phase, "tasks": replacement}
    validate_tasks(trial)
    done_ids = {t["id"] for t in replacement if t["status"] == "done"}
    if task["status"] in {"ready", "in_progress", "testing", "review"} and not set(task["dependencies"]) <= done_ids:
        raise GateError("Dependencies must be done before work starts")
    phase["tasks"] = replacement
    persist(root, board)


def ready_tasks(phase: dict) -> list:
    validate_tasks(phase)
    done_ids = {t["id"] for t in phase["tasks"] if t["status"] == "done"}
    return sorted((t for t in phase["tasks"] if t["status"] in {"backlog", "ready"}
                   and set(t["dependencies"]) <= done_ids), key=lambda t: (t["priority"], t["id"]))


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, timeout=20)
    if result.returncode:
        raise GateError(result.stderr.decode(errors="replace").strip() or "Git command failed")
    return result.stdout.decode("utf-8", errors="surrogateescape").rstrip("\r\n")


def operational(path: str) -> bool:
    return path in {BOARD, PROGRESS} or path.startswith(".autonomy/")


def snapshot(root: Path) -> dict:
    head = git(root, "rev-parse", "HEAD")
    paths = git(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z").split("\0")
    hasher = hashlib.sha256()
    for value in sorted(set(paths)):
        if not value or operational(value):
            continue
        path = local(root, value)
        hasher.update(value.encode("utf-8", errors="surrogateescape") + b"\0")
        hasher.update(path.read_bytes() if path.is_file() else b"<missing>")
    return {"head": head, "source_sha256": hasher.hexdigest()}


def integrated(root: Path, phase: dict) -> None:
    if git(root, "branch", "--show-current") != phase["approval"]["development_branch"]:
        raise GateError("Current branch is not the approved development branch")
    changes = git(root, "status", "--porcelain", "-z").split("\0")
    for change in changes:
        if change and not operational(change[3:] if len(change) > 3 else change):
            raise GateError("Source changes must be integrated/committed before completion")


def evidence_report(root: Path, task: dict, key: str, kind: str, current: dict, role: str) -> dict:
    evidence = task.get("evidence", {})
    if not isinstance(evidence, dict):
        raise GateError("Task evidence must be an object")
    if evidence.get("snapshot") != current:
        raise GateError(f"{task['id']}: task evidence is stale or absent")
    report = json.loads(local(root, evidence.get(key, "")).read_text(encoding="utf-8"))
    if not isinstance(report, dict):
        raise GateError(f"{kind} report must be an object")
    if report.get("kind") != kind or report.get("task_id") != task["id"] or report.get("snapshot") != current or report.get("role") != role:
        raise GateError(f"{task['id']}: {kind} evidence does not match task, source, or role")
    if report.get("status") != "passed":
        raise GateError(f"{task['id']}: {kind} has not passed")
    return report


def quality_evidence(root: Path, task: dict, current: dict) -> None:
    acceptance = evidence_report(root, task, "acceptance_report", "acceptance", current, "qa_engineer")
    criteria = acceptance.get("criteria", [])
    if not isinstance(criteria, list) or not all(isinstance(x, dict) for x in criteria):
        raise GateError("Acceptance criteria report must be a list of objects")
    if {x.get("criterion") for x in criteria} != set(task["acceptance_criteria"]) or any(
        x.get("passed") is not True or not x.get("evidence") for x in criteria
    ):
        raise GateError("Every acceptance criterion needs passing QA evidence")
    evidence_report(root, task, "qa_report", "qa", current, "qa_engineer")
    review = evidence_report(root, task, "review_report", "review", current, "code_reviewer")
    findings = review.get("findings")
    if not isinstance(findings, list) or not all(isinstance(x, dict) for x in findings):
        raise GateError("Review must explicitly list findings (empty is allowed)")
    for finding in findings:
        if finding.get("priority") not in {"P0", "P1", "P2", "P3"}:
            raise GateError("Invalid review severity")
        if finding["priority"] in {"P0", "P1"} and finding.get("resolved") is not True:
            raise GateError("Unresolved critical/high review finding")


def phase_coverage(phase: dict) -> None:
    validate_tasks(phase)
    if not phase["tasks"] or any(t["status"] != "done" for t in phase["tasks"]):
        raise GateError("Phase has unfinished tasks")
    covered = {r for t in phase["tasks"] for r in t["requirements"]}
    if covered != set(phase["contract"]["requirements"]):
        raise GateError("Approved requirements are not all covered by completed tasks")
