"""Bounded phase runner. Native Codex remains responsible for development/delegation."""
from __future__ import annotations

import argparse
import copy
import json
import os
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

import core
from core import (GateError, WorkspaceLock, approve, atomic_json, check_approval, digest,
                  file_digest, git, initialize, integrated, local, now, persist, phase_coverage,
                  phase_of, quality_evidence, read_board, ready_tasks, slug, snapshot, validate_tasks)

SCHEMA = Path(__file__).with_name("run-result.schema.json")


class BudgetExpired(GateError):
    pass


class WindowsProcessTree:
    """Assign a suspended child to a kill-on-close Job before any code can run."""
    def __init__(self, proc):
        import ctypes
        from ctypes import wintypes as w
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        self.handle = None
        size = ctypes.c_size_t
        class Basic(ctypes.Structure):
            _fields_ = [("process_time", ctypes.c_longlong), ("job_time", ctypes.c_longlong),
                        ("flags", w.DWORD), ("min_ws", size), ("max_ws", size),
                        ("active", w.DWORD), ("affinity", size), ("priority", w.DWORD), ("schedule", w.DWORD)]
        class IO(ctypes.Structure):
            _fields_ = [(name, ctypes.c_ulonglong) for name in ("read_ops", "write_ops", "other_ops", "read_bytes", "write_bytes", "other_bytes")]
        class Extended(ctypes.Structure):
            _fields_ = [("basic", Basic), ("io", IO), ("process_memory", size), ("job_memory", size),
                        ("peak_process", size), ("peak_job", size)]
        class ThreadEntry(ctypes.Structure):
            _fields_ = [("dwSize", w.DWORD), ("cntUsage", w.DWORD), ("thread", w.DWORD),
                        ("owner", w.DWORD), ("base", w.LONG), ("delta", w.LONG), ("flags", w.DWORD)]
        signatures = {
            "CreateJobObjectW": ([w.LPVOID, w.LPCWSTR], w.HANDLE),
            "SetInformationJobObject": ([w.HANDLE, ctypes.c_int, w.LPVOID, w.DWORD], w.BOOL),
            "AssignProcessToJobObject": ([w.HANDLE, w.HANDLE], w.BOOL),
            "CreateToolhelp32Snapshot": ([w.DWORD, w.DWORD], w.HANDLE),
            "Thread32First": ([w.HANDLE, ctypes.POINTER(ThreadEntry)], w.BOOL),
            "Thread32Next": ([w.HANDLE, ctypes.POINTER(ThreadEntry)], w.BOOL),
            "OpenThread": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            "ResumeThread": ([w.HANDLE], w.DWORD), "CloseHandle": ([w.HANDLE], w.BOOL),
        }
        for name, (arguments, result) in signatures.items():
            method = getattr(self.api, name)
            method.argtypes, method.restype = arguments, result
        self.handle = self.api.CreateJobObjectW(None, None)
        info = Extended()
        info.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        try:
            if not self.handle or not self.api.SetInformationJobObject(self.handle, 9, ctypes.byref(info), ctypes.sizeof(info)):
                raise GateError("Cannot create child process containment")
            if not self.api.AssignProcessToJobObject(self.handle, int(proc._handle)):
                raise GateError("Cannot contain child process; refusing an unattended run")
            threads = self.api.CreateToolhelp32Snapshot(4, 0)  # TH32CS_SNAPTHREAD
            if threads == ctypes.c_void_p(-1).value:
                raise GateError("Cannot inspect suspended child thread")
            resumed = False
            try:
                entry = ThreadEntry()
                entry.dwSize = ctypes.sizeof(entry)
                more = self.api.Thread32First(threads, ctypes.byref(entry))
                while more:
                    if entry.owner == proc.pid:
                        thread = self.api.OpenThread(2, False, entry.thread)
                        if thread:
                            try:
                                resumed = self.api.ResumeThread(thread) != 0xFFFFFFFF
                            finally:
                                self.api.CloseHandle(thread)
                        break
                    more = self.api.Thread32Next(threads, ctypes.byref(entry))
            finally:
                self.api.CloseHandle(threads)
            if not resumed:
                raise GateError("Cannot resume safely contained child")
        except BaseException:
            self.close()
            proc.kill()
            proc.wait(timeout=5)
            raise

    def close(self):
        if self.handle:
            self.api.CloseHandle(self.handle)
            self.handle = None


def stop_process(proc):
    """Stop only this spawned process tree; never kill unrelated Codex sessions."""
    if proc.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True, timeout=10)
    else:
        import signal
        os.killpg(proc.pid, signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        if os.name != "nt":
            import signal
            os.killpg(proc.pid, signal.SIGKILL)
        else:
            proc.kill()
        proc.wait(timeout=5)


def invoke(argv: list[str], root: Path, log: Path, seconds: float, prompt: str | None = None) -> dict:
    log.parent.mkdir(parents=True, exist_ok=True)
    options = {"start_new_session": True} if os.name != "nt" else {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP | 4}
    started = time.monotonic()
    proc = subprocess.Popen(argv, cwd=root, stdin=subprocess.PIPE if prompt is not None else subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                            errors="replace", **options)
    tree = WindowsProcessTree(proc) if os.name == "nt" else None
    lines = queue.Queue()
    def reader():
        for line in proc.stdout:
            lines.put(line)
        lines.put(None)
    timed_out, usage, session_id = False, 0, None
    complete = False
    try:
        threading.Thread(target=reader, daemon=True).start()
        if prompt is not None:
            proc.stdin.write(prompt)
            proc.stdin.close()
        with log.open("w", encoding="utf-8") as output:
            while not complete:
                if time.monotonic() - started >= seconds:
                    timed_out = True
                    stop_process(proc)
                    if tree:
                        tree.close()  # also close descendant pipes after a parent exits
                try:
                    line = lines.get(timeout=0.1)
                except queue.Empty:
                    # Read through the reader's EOF sentinel even after a fast exit.
                    continue
                if line is None:
                    complete = True
                    continue
                output.write(line)
                output.flush()
                try:
                    event = json.loads(line)
                    if not isinstance(event, dict):
                        continue
                    if event.get("type") == "thread.started":
                        session_id = event.get("thread_id")
                    if event.get("type") == "turn.completed":
                        counts = event.get("usage", {})
                        usage += counts.get("input_tokens", 0) + counts.get("output_tokens", 0)
                except (ValueError, TypeError):
                    pass
            remaining = max(0.1, seconds - (time.monotonic() - started))
            try:
                proc.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                timed_out = True
                stop_process(proc)
    finally:
        stop_process(proc)
        if tree:
            tree.close()
        proc.stdout.close()
    return {"returncode": proc.returncode, "timed_out": timed_out,
            "seconds": time.monotonic() - started, "session_id": session_id,
            "reported_parent_tokens": usage, "log": str(log.relative_to(root))}


def execute_checks(root: Path, phase: dict, ids: list[str], out: Path, deadline: float) -> list[dict]:
    results = []
    for check_id in sorted(set(ids)):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise BudgetExpired("Runtime budget exhausted before verification")
        argv = phase["contract"]["checks"][check_id]
        safe_id = digest(check_id)[:12]
        result = invoke(argv, root, out / f"check-{safe_id}.log", remaining)
        result["check_id"] = check_id
        results.append(result)
        if result["timed_out"]:
            raise BudgetExpired(f"Verification budget expired during {check_id}; resume it, do not create a defect")
        if result["returncode"] != 0:
            raise GateError(f"Check {check_id} failed; evidence: {result['log']}")
    return results


def verify_task(root: Path, phase: dict, task: dict, out: Path, deadline: float) -> None:
    integrated(root, phase)
    current = snapshot(root)
    quality_evidence(root, task, current)
    checks = execute_checks(root, phase, task["test_requirements"], out, deadline)
    integrated(root, phase)
    if snapshot(root) != current:
        raise GateError("Verification changed source; regenerate evidence and review")
    task["verification"] = {"snapshot": current, "checks": checks, "verified_at": now(),
                            "report_sha256": {k: file_digest(local(root, task["evidence"][k]))
                            for k in ("acceptance_report", "qa_report", "review_report")}}
    task["status"] = "done"
    task["blocker"] = None


def record_failure(phase: dict, task: dict, message: str) -> None:
    task["retry_count"] += 1
    task["blocker"] = message
    task.setdefault("failures", []).append({"at": now(), "message": message, "category": "validation"})
    if task.get("type") == "defect":
        task["status"] = "blocked" if task["retry_count"] % 3 == 0 else "in_progress"
        task["needs_different_diagnosis"] = task["retry_count"] % 3 == 0
        return
    base = task["id"] + "_FIX"
    existing = next((t for t in phase["tasks"] if t.get("type") == "defect"
                     and t.get("parent_task") == task["id"] and t["status"] != "done"), None)
    defect_id = existing["id"] if existing else base
    used = {t["id"] for t in phase["tasks"]}
    number = 2
    while not existing and defect_id in used:
        defect_id = f"{base}_{number}"
        number += 1
    task["status"] = "blocked"
    task["blocked_by"] = defect_id
    if existing:
        existing["status"] = "blocked" if task["retry_count"] >= 3 else "in_progress"
        existing["blocker"] = message
        existing["retry_count"] += 1
        existing["needs_different_diagnosis"] = task["retry_count"] >= 3
    else:
        defect = copy.deepcopy(task)
        for key in ("evidence", "verification", "blocked_by", "failures"):
            defect.pop(key, None)
        defect.update({"id": defect_id, "type": "defect", "parent_task": task["id"],
                       "description": "Fix validation failure for " + task["id"], "dependencies": [],
                       "status": "backlog", "retry_count": 0,
                       "acceptance_criteria": ["Resolve recorded validation failure: " + message]})
        if task["retry_count"] >= 3:
            defect.update({"retry_count": task["retry_count"], "status": "blocked", "needs_different_diagnosis": True})
        if defect["assigned_agent"] in {"qa_engineer", "code_reviewer"}:
            defect["assigned_agent"] = "flutter_flame_developer"
        phase["tasks"].append(defect)


def verify_phase(root: Path, name: str, phase: dict, out: Path, deadline: float) -> None:
    phase_coverage(phase)
    integrated(root, phase)
    current = snapshot(root)
    evidence = phase.get("evidence", {})
    if not isinstance(evidence, dict):
        raise GateError("Phase evidence must be an object")
    qa = json.loads(local(root, evidence.get("qa_report", "")).read_text(encoding="utf-8"))
    if not isinstance(qa, dict):
        raise GateError("Final QA report must be an object")
    if (qa.get("kind"), qa.get("phase"), qa.get("role"), qa.get("status"), qa.get("snapshot")) != (
        "phase_qa", name, "qa_engineer", "passed", current):
        raise GateError("Final phase-wide QA is missing or stale")
    requirements = qa.get("requirements", [])
    if not isinstance(requirements, list) or not all(isinstance(x, dict) for x in requirements):
        raise GateError("Final QA requirements must be a list of objects")
    if ({x.get("id") for x in requirements} != set(phase["contract"]["requirements"])
        or any(x.get("passed") is not True or not x.get("evidence") for x in requirements)):
        raise GateError("Final QA must verify every approved requirement")
    acceptance = qa.get("task_acceptance", [])
    if not isinstance(acceptance, list) or not all(isinstance(x, dict) for x in acceptance):
        raise GateError("Final task acceptance must be a list of objects")
    if {x.get("task_id") for x in acceptance} != {t["id"] for t in phase["tasks"]}:
        raise GateError("Final QA must cover every task's acceptance criteria")
    for task in phase["tasks"]:
        criteria = next(x.get("criteria") for x in acceptance if x.get("task_id") == task["id"])
        if not isinstance(criteria, list) or not all(isinstance(x, dict) for x in criteria):
            raise GateError("Final task criteria must be a list of objects")
        if ({x.get("criterion") for x in criteria} != set(task["acceptance_criteria"])
            or any(x.get("passed") is not True or not x.get("evidence") for x in criteria)):
            raise GateError("Task acceptance evidence is stale/incomplete at final phase snapshot")
    report = json.loads(local(root, evidence.get("review_report", "")).read_text(encoding="utf-8"))
    if not isinstance(report, dict):
        raise GateError("Final review report must be an object")
    if (report.get("kind"), report.get("phase"), report.get("role"), report.get("status"), report.get("snapshot")) != (
        "phase_review", name, "code_reviewer", "passed", current):
        raise GateError("Final independent phase review is missing or stale")
    reviewed_tasks = report.get("task_ids")
    if not isinstance(reviewed_tasks, list) or not all(isinstance(x, str) for x in reviewed_tasks):
        raise GateError("Final review task_ids must be a string list")
    if set(reviewed_tasks) != {t["id"] for t in phase["tasks"]}:
        raise GateError("Final review must cover every phase task")
    if (not isinstance(report.get("findings"), list)
        or not all(isinstance(x, dict) for x in report["findings"]) or any(
        f.get("priority") not in {"P0", "P1", "P2", "P3"} or
        (f.get("priority") in {"P0", "P1"} and f.get("resolved") is not True) for f in report["findings"]
    )):
        raise GateError("Final phase review has invalid/unresolved high findings")
    release = local(root, evidence.get("release_candidate", ""))
    if not release.is_file() or not release.read_text(encoding="utf-8").strip():
        raise GateError("Release candidate documentation is required")
    checks = set(phase["contract"]["required_phase_checks"])
    checks.update(c for task in phase["tasks"] for c in task["test_requirements"])
    results = execute_checks(root, phase, list(checks), out, deadline)
    integrated(root, phase)
    if snapshot(root) != current:
        raise GateError("Source changed during final verification")
    phase["verification"] = {"snapshot": current, "checks": results, "verified_at": now(),
                             "qa_sha256": file_digest(local(root, evidence["qa_report"])),
                             "review_sha256": file_digest(local(root, evidence["review_report"])),
                             "release_sha256": file_digest(release)}
    phase["execution_status"] = "complete"
    phase["last_message"] = "Verified release candidate prepared for user acceptance; no deployment performed."


def lead_prompt(root: Path, name: str, phase: dict, state: dict, seconds: float) -> str:
    return f"""Act as the primary Tech Lead for phase {name}. This is an explicitly authorized
phase execution within its approved scope, not authorization for a different phase.
Read AGENTS.md, docs/development/autonomous-execution.md, docs/development/task-board.json,
docs/development/progress.md, {phase['scope_path']}, approved ADRs, Git state and previous logs.
Use the existing six native role definitions/model assignments. Do not silently substitute
models. At most three bounded native specialists; only you mutate the task board.
Scope and requirement/check contract are frozen by approval. Do not change approval fields,
contract, supervisor code, scripts/autonomy, runtime state, or the workspace lock. Do not run
the approve command. Report any human decision as needs_approval and persist its exact reason.
Operate only on development branch {phase['approval']['development_branch']}. Preserve user
changes; no destructive commands, production data/deploy, app publishing, protected merges,
paid services, major architecture or auth/privacy/scope changes without explicit approval.
Continue the highest-priority ready tasks; do not stop after a feature. Split into small tasks
with every required board field, requirement mapping, acceptance criteria and approved check IDs.
Use scripts/autonomy/board.py task --phase {name} --input FILE for atomic state changes.
Tasks start backlog and move ready -> in_progress -> testing -> review. Never mark done;
the supervisor independently reruns checks and marks completion after your checkpoint.
Implementation, QA and independent review are required; failure creates bounded fix tasks.
After three failed attempts seek a different diagnosis, document blockers, and continue
independent work. Interrupted in_progress/testing work requires inspection before retry.
Commit integrated changes only on the approved development branch, excluding unrelated user
changes. Do not amend existing history or switch branches automatically.
Use board.py snapshot after integration. Task evidence binds that snapshot and contains
acceptance_report, qa_report, review_report paths. Report JSON formats are described in the
execution guide. Put reports/check logs under .autonomy/evidence/{name}/, not source code.
Only return a checkpoint after meaningful progress or when verification is ready, blocked,
approval is needed, or the remaining slice budget ({int(seconds)} seconds) requires it.
If tasks reach review, return continue so supervisor can verify/unlock their dependents.
After all tasks are verified done, obtain independent final phase_review covering all task IDs
and fresh phase_qa for every requirement and task criterion at the final current snapshot.
Prepare release documentation with known/unverified limitations. Set phase evidence qa_report,
review_report and release_candidate, then return complete (a request for
verification, not a claim that the supervisor will accept). No required check may be skipped
and counted as passed. Persist state after meaningful transitions. Your structured response
must match the supplied schema: phase={name}, outcome, summary. Outcome is one of continue,
needs_approval, blocked, complete. The supervisor already holds the lock; do not launch another
supervisor or a separate goal. This run's persistent usage: {json.dumps(state.get('budget', {}))}.
"""


def cli_preflight(exe: str, root: Path) -> None:
    if os.name != "nt":
        raise GateError("Live supervised execution currently requires verified Windows Job containment")
    version = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=10)
    if version.returncode or "0.162." not in version.stdout:
        raise GateError("Select the tested Codex 0.162 runtime; other versions require compatibility validation")
    # Read effective native settings before making a model call. An untrusted project
    # can otherwise silently load defaults instead of the requested six-role team.
    proc = subprocess.Popen([exe, "--strict-config", "app-server", "--stdio"], cwd=root,
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            text=True, encoding="utf-8")
    messages = queue.Queue()
    def reader():
        for line in proc.stdout:
            try:
                messages.put(json.loads(line))
            except ValueError:
                pass
    threading.Thread(target=reader, daemon=True).start()
    def request(number, method, params):
        proc.stdin.write(json.dumps({"id": number, "method": method, "params": params}) + "\n")
        proc.stdin.flush()
        until = time.monotonic() + 10
        while time.monotonic() < until:
            message = messages.get(timeout=max(0.01, until - time.monotonic()))
            if message.get("id") == number:
                if "error" in message:
                    raise GateError(f"Native configuration read failed: {message['error']}")
                return message["result"]
        raise GateError("Native configuration read timed out")
    try:
        request(1, "initialize", {"clientInfo": {"name": "phase_preflight", "version": "1.0"}})
        proc.stdin.write(json.dumps({"method": "initialized", "params": {}}) + "\n")
        proc.stdin.flush()
        config = request(2, "config/read", {"cwd": str(root), "includeLayers": True})["config"]
        agents = config.get("agents", {})
        expected = {"tech_lead", "architect", "backend_developer", "flutter_flame_developer", "qa_engineer", "code_reviewer"}
        # Older supported Codex runtimes deserialize [agents] as role tables only;
        # scalar settings there (including enabled/max_concurrent_threads_per_session)
        # fail config loading. Multi-agent tools default to enabled. The project
        # instructions cap active delegates at three for those runtimes.
        if (config.get("model") != "gpt-6-astra" or config.get("model_reasoning_effort") != "high"
            or not expected <= agents.keys()):
            raise GateError("Native team role configuration is incomplete or overridden")
        import tomllib
        pairs = {"tech_lead": ("gpt-6-astra", "high"), "architect": ("gpt-6-astra", "high"),
                 "backend_developer": ("gpt-6-sol", "medium"), "flutter_flame_developer": ("gpt-6-sol", "medium"),
                 "qa_engineer": ("gpt-5.6-terra", "medium"), "code_reviewer": ("gpt-6-sol", "high")}
        for role, pair in pairs.items():
            path = (root / ".codex/agents" / (role + ".toml")).resolve()
            if Path(agents[role].get("config_file", "")).resolve() != path:
                raise GateError(f"Native role {role} resolves outside this project's definition")
            data = tomllib.loads(path.read_text(encoding="utf-8"))
            if (data.get("model"), data.get("model_reasoning_effort")) != pair:
                raise GateError(f"Unexpected model/effort for {role}; no silent replacement allowed")
    except (queue.Empty, BrokenPipeError, KeyError) as error:
        raise GateError("Cannot verify effective native team configuration; no model run started") from error
    finally:
        stop_process(proc)
        proc.stdin.close()
        proc.stdout.close()


def run_phase(args) -> int:
    root = args.root.resolve()
    name = slug(args.phase)
    with WorkspaceLock(root):
        board = read_board(root)
        phase = phase_of(board, name)
        check_approval(root, phase)
        validate_tasks(phase)
        branch = git(root, "branch", "--show-current")
        if branch != phase["approval"]["development_branch"]:
            raise GateError("Open the approved development branch; runner does not initialize/switch Git")
        git(root, "rev-parse", "HEAD")
        if args.max_tokens is not None or args.max_cost is not None:
            raise GateError("Strict aggregate token/cost budgets are unavailable in this CLI interface; do not run until accounting is verified")
        state_path = root / f".autonomy/state/{name}.json"
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {
            "phase": name, "session_id": None, "budget": {"seconds": 0.0, "launches": 0, "reported_parent_tokens": 0},
            "verified_tasks": {}, "failures": 0, "no_progress": 0,
        }
        if args.renew_budget:
            state["budget"] = {"seconds": 0.0, "launches": 0, "reported_parent_tokens": 0}
        elif state.get("active_run"):
            # A supervisor crash loses the measured stop time. Charge the full reserved
            # slice rather than giving a restarted process a fresh budget.
            state["budget"]["seconds"] += state["active_run"]["reserved_seconds"]
        state.pop("active_run", None)
        if args.retry_after_diagnosis:
            state["failures"], state["no_progress"] = 0, 0
        elif state["failures"] >= 3:
            raise GateError("Three failed CLI launches require a new diagnosis before explicit retry")
        if phase.get("execution_status") == "complete":
            receipt = digest({"verification": phase.get("verification"), "evidence": phase.get("evidence"),
                              "verified_tasks": state["verified_tasks"]})
            if state.get("phase_receipt") != receipt:
                raise GateError("Phase completion has no matching supervisor receipt; final verification required")
            integrated(root, phase)
            phase_coverage(phase)
            if phase.get("verification", {}).get("snapshot") != snapshot(root):
                raise GateError("Completed phase source changed; approval/revalidation decision required")
            for task in phase["tasks"]:
                if state["verified_tasks"].get(task["id"]) != digest(task):
                    raise GateError("Completed task receipt changed")
                for key, expected_hash in task.get("verification", {}).get("report_sha256", {}).items():
                    if file_digest(local(root, task["evidence"][key])) != expected_hash:
                        raise GateError("Completed task report changed")
            for key, field in (("qa_report", "qa_sha256"), ("review_report", "review_sha256"), ("release_candidate", "release_sha256")):
                if file_digest(local(root, phase.get("evidence", {}).get(key, ""))) != phase["verification"].get(field):
                    raise GateError("Completed phase evidence changed")
            print(f"{name}: complete: verified candidate unchanged; no model launched.")
            return 0
        cli_preflight(args.codex, root)
        baseline_approval = copy.deepcopy(phase["approval"])
        start = time.monotonic()
        previous_seconds = state["budget"]["seconds"]
        deadline = start + args.runtime_seconds - previous_seconds
        def checkpoint(message, status):
            phase["last_message"], phase["execution_status"] = message, status
            state["budget"]["seconds"] = previous_seconds + time.monotonic() - start
            state["updated_at"] = now()
            # Receipt first: a crash may leave an older review candidate on the board,
            # which can safely be reverified, but never a done task with no receipt.
            atomic_json(state_path, state)
            persist(root, board)
            print(f"{name}: {status}: {message}", flush=True)
        for task in phase["tasks"]:
            if task["status"] == "done" and state["verified_tasks"].get(task["id"]) != digest(task):
                raise GateError("Unverified/modified done task found; inspect persistent evidence")
        checkpoint("Execution started from persistent phase state.", "running")
        while time.monotonic() < deadline and state["budget"]["launches"] < args.max_launches:
            before = digest({"tasks": phase["tasks"], "evidence": phase.get("evidence")})
            launch = state["budget"]["launches"] + 1
            out = root / f".autonomy/runs/{name}/{launch:04d}"
            out.mkdir(parents=True, exist_ok=True)
            result_path = out / "result.json"
            argv = [args.codex, "--strict-config", "exec"]
            if getattr(args, "automatic_review", False):
                # Native preset selects workspace-write and conflicts with --sandbox.
                argv += ["--approve-for-me"]
            else:
                argv += ["--sandbox", "workspace-write"]
            if state["session_id"]:
                argv += ["resume", state["session_id"]]
            argv += ["--json", "--output-schema", str(SCHEMA), "--output-last-message", str(result_path), "-"]
            # Resume inherits original permission policy; sandbox flag remains on exec parent.
            seconds = min(args.slice_seconds, deadline - time.monotonic())
            state["budget"]["launches"] = launch
            state["active_run"] = {"started_at": now(), "reserved_seconds": seconds, "launch": launch}
            atomic_json(state_path, state)  # reserve launch before spawn, including interrupted runs
            outcome = invoke(argv, root, out / "events.jsonl", seconds, lead_prompt(root, name, phase, state, seconds))
            state.pop("active_run", None)
            if outcome["session_id"]:
                state["session_id"] = outcome["session_id"]
            state["budget"]["reported_parent_tokens"] += outcome["reported_parent_tokens"]
            board = read_board(root)
            phase = phase_of(board, name)
            if phase["approval"] != baseline_approval:
                raise GateError("Lead changed approval metadata; execution stopped")
            check_approval(root, phase)
            validate_tasks(phase)
            for task in phase["tasks"]:
                if task["status"] == "done" and state["verified_tasks"].get(task["id"]) != digest(task):
                    raise GateError("Lead declared completion without supervisor verification")
            if outcome["returncode"] or outcome["timed_out"]:
                state["failures"] += 1
                checkpoint(f"Interrupted/failed CLI run; inspect {outcome['log']} before resuming.", "interrupted")
                # Do not overlap an unknown child writer or retry the same failure automatically.
                return 2
            try:
                response = json.loads(result_path.read_text(encoding="utf-8"))
                if (not isinstance(response, dict) or response.get("phase") != name or response.get("outcome") not in
                    {"continue", "needs_approval", "blocked", "complete"} or not isinstance(response.get("summary"), str)):
                    raise GateError("Malformed phase result")
            except (ValueError, OSError):
                checkpoint("CLI did not produce a valid structured checkpoint.", "blocked")
                return 2
            verification_failed = False
            for task in list(phase["tasks"]):
                if task["status"] == "review":
                    try:
                        verify_task(root, phase, task, out / task["id"], deadline)
                        state["verified_tasks"][task["id"]] = digest(task)
                        for parent in phase["tasks"]:
                            if parent.get("blocked_by") == task["id"]:
                                parent["status"] = "ready"
                                parent["blocker"] = None
                                parent.pop("blocked_by", None)
                    except BudgetExpired as error:
                        checkpoint(str(error), "budget_exhausted")
                        return 2
                    except (GateError, OSError, ValueError) as error:
                        record_failure(phase, task, str(error))
                        verification_failed = True
            if response["outcome"] == "complete" and not verification_failed:
                try:
                    verify_phase(root, name, phase, out / "phase", deadline)
                    state["phase_receipt"] = digest({"verification": phase.get("verification"),
                        "evidence": phase.get("evidence"), "verified_tasks": state["verified_tasks"]})
                    checkpoint(phase["last_message"], "complete")
                    return 0
                except BudgetExpired as error:
                    checkpoint(str(error), "budget_exhausted")
                    return 2
                except (GateError, OSError, ValueError) as error:
                    phase["last_message"] = f"Completion rejected: {error}"
            if response["outcome"] == "needs_approval":
                # Verify independent submitted candidates before stopping. The Lead
                # blocks only approval-dependent tasks and may finish other ready work.
                approval_pending = any(t["status"] == "blocked" for t in phase["tasks"])
                if not approval_pending or not ready_tasks(phase):
                    checkpoint(response["summary"], "needs_approval")
                    return 2
                phase["last_message"] = response["summary"] + " Independent ready tasks remain authorized."
            changed = digest({"tasks": phase["tasks"], "evidence": phase.get("evidence")}) != before
            state["no_progress"] = 0 if changed else state["no_progress"] + 1
            if state["no_progress"] >= 2:
                checkpoint("Two checkpoints without progress; different diagnosis or user decision needed.", "blocked")
                return 2
            if response["outcome"] == "blocked" and not ready_tasks(phase) and not any(
                t["status"] in {"in_progress", "testing", "review"} for t in phase["tasks"]
            ):
                checkpoint(response["summary"], "blocked")
                return 2
            checkpoint(phase["last_message"] if phase["last_message"].startswith("Completion rejected")
                       else response["summary"], "running")
        checkpoint("Execution budget exhausted; unfinished work preserved. Explicit renewal required.", "budget_exhausted")
        return 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init")
    init.add_argument("--phase", required=True)
    init.add_argument("--scope", required=True)
    status = commands.add_parser("status")
    status.add_argument("--phase", required=True)
    approval = commands.add_parser("approve", help="Operator only: record external human approval")
    approval.add_argument("--phase", required=True)
    approval.add_argument("--branch", required=True)
    approval.add_argument("--approved-by", required=True)
    approval.add_argument("--contract", type=Path, required=True)
    revise = commands.add_parser("revise-approval", help="Operator only: record external approval of a revised scope/contract")
    revise.add_argument("--phase", required=True)
    revise.add_argument("--approved-by", required=True)
    revise.add_argument("--contract", type=Path, required=True)
    run = commands.add_parser("run")
    run.add_argument("--phase", required=True)
    run.add_argument("--codex", required=True, help="Path to verified Codex runtime")
    run.add_argument("--runtime-seconds", type=int, default=3600)
    run.add_argument("--slice-seconds", type=int, default=600)
    run.add_argument("--max-launches", type=int, default=6)
    run.add_argument("--max-tokens", type=int)
    run.add_argument("--max-cost", type=float, help="Fail closed until aggregate billing accounting is supported")
    run.add_argument("--automatic-review", action="store_true",
                     help="Route individual escalation requests through native automatic review; keep workspace sandbox")
    run.add_argument("--renew-budget", action="store_true", help="Explicit operator-authorized budget renewal")
    run.add_argument("--retry-after-diagnosis", action="store_true", help="Operator only: retry after a documented new diagnosis")
    args = parser.parse_args()
    args.root = args.root.resolve()
    try:
        if args.command == "run":
            if min(args.runtime_seconds, args.slice_seconds, args.max_launches) <= 0:
                raise GateError("Runtime/slice/launch budgets must be positive")
            return run_phase(args)
        if args.command == "status":
            print(json.dumps(phase_of(read_board(args.root), args.phase), indent=2))
        else:
            with WorkspaceLock(args.root):
                if args.command == "init":
                    initialize(args.root, args.phase, args.scope)
                elif args.command == "revise-approval":
                    core.revise_approval(args.root, read_board(args.root), args.phase, args.approved_by,
                                         json.loads(args.contract.read_text(encoding="utf-8")))
                else:
                    approve(args.root, read_board(args.root), args.phase, args.branch, args.approved_by,
                            json.loads(args.contract.read_text(encoding="utf-8")))
            print("Phase state persisted; no development run started.")
        return 0
    except (GateError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Blocked: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
