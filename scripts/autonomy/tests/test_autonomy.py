"""Local orchestration regression tests; no models, cloud calls or application code."""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import core
import supervisor


class PhaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="autonomy-test-")
        self.root = Path(self.directory.name)
        (self.root / "scope.md").write_text("Approved test fixture scope", encoding="utf-8")
        self.board = core.initialize(self.root, "MVP", "scope.md")
        self.contract = {"requirements": ["R1"], "checks": {"TEST": [sys.executable, "-c", "print(123)"]},
                         "required_phase_checks": ["TEST"]}
        core.approve(self.root, self.board, "mvp", "development/test", "test-only approval fixture", self.contract)
        self.phase = core.phase_of(self.board, "mvp")
        self.task = {"id": "T1", "epic": "E1", "feature": "F1", "description": "Fixture task",
                     "assigned_agent": "flutter_flame_developer", "priority": 1, "dependencies": [],
                     "acceptance_criteria": ["Fixture works"], "relevant_files": ["fixture.py"],
                     "test_requirements": ["TEST"], "requirements": ["R1"], "subtasks": [],
                     "status": "backlog", "retry_count": 0}

    def tearDown(self):
        # TemporaryDirectory owns this exact test directory; no project files are deleted.
        self.directory.cleanup()

    def reports(self, task=None, current=None):
        task = task or self.task
        current = current or {"head": "abc", "source_sha256": "def"}
        task["evidence"] = {"snapshot": current}
        for kind, role in [("acceptance", "qa_engineer"), ("qa", "qa_engineer"), ("review", "code_reviewer")]:
            path = f".autonomy/{kind}.json"
            report = {"kind": kind, "role": role, "task_id": task["id"], "snapshot": current, "status": "passed"}
            if kind == "acceptance":
                report["criteria"] = [{"criterion": x, "passed": True, "evidence": "Executed fixture"} for x in task["acceptance_criteria"]]
            if kind == "review":
                report["findings"] = []
            core.atomic_json(self.root / path, report)
            task["evidence"][kind + "_report"] = path
        return current

    def args(self, **kw):
        values = dict(root=self.root, phase="mvp", codex="fake-codex", max_tokens=None,
                      max_cost=None, retry_after_diagnosis=False, renew_budget=False,
                      runtime_seconds=60, slice_seconds=10, max_launches=6)
        values.update(kw)
        return SimpleNamespace(**values)

    def run_fake(self, outcomes, mutate=None, **kw):
        calls = []
        real_invoke = supervisor.invoke
        def invoke(argv, root, log, seconds, prompt=None):
            if prompt is None:
                return real_invoke(argv, root, log, seconds)
            calls.append(argv)
            index = len(calls) - 1
            if mutate:
                mutate(index)
            outcome = outcomes[min(index, len(outcomes) - 1)]
            core.atomic_json(log.parent / "result.json", {"phase": "mvp", "outcome": outcome, "summary": "fixture"})
            return {"returncode": 0, "timed_out": False, "seconds": .01, "session_id": "fixture-session",
                    "reported_parent_tokens": 12, "log": str(log.relative_to(root))}
        with patch.object(supervisor, "cli_preflight"), patch.object(supervisor, "git", return_value="development/test"), patch.object(supervisor, "invoke", side_effect=invoke):
            result = supervisor.run_phase(self.args(**kw))
        return result, calls

    def test_generic_phase_and_path_guards(self):
        core.initialize(self.root, "Reading", "scope.md")
        self.assertIn("reading", core.read_board(self.root)["phases"])
        with self.assertRaises(core.GateError):
            core.slug("../MVP")
        with self.assertRaises(core.GateError):
            core.local(self.root, "../outside")

    def test_automatic_review_preserves_sandbox_and_exact_resume(self):
        result, calls = self.run_fake(["continue", "blocked"], automatic_review=True)
        self.assertEqual(result, 2)
        self.assertEqual(len(calls), 2)
        for call in calls:
            self.assertIn("--approve-for-me", call)
            self.assertNotIn("--sandbox", call)  # native preset selects workspace-write
            self.assertNotIn("--dangerously-bypass-approvals-and-sandbox", call)
        self.assertIn("resume", calls[1])
        self.assertEqual(calls[1][calls[1].index("resume") + 1], "fixture-session")

    def test_default_run_does_not_change_approval_routing(self):
        _, calls = self.run_fake(["blocked"])
        self.assertNotIn("--approve-for-me", calls[0])
        self.assertEqual(calls[0][calls[0].index("--sandbox") + 1], "workspace-write")

    def test_init_never_overwrites(self):
        with self.assertRaises(core.GateError):
            core.initialize(self.root, "mvp", "scope.md")

    def test_missing_approval_blocks_before_model(self):
        self.phase["approval"]["status"] = "pending"
        core.persist(self.root, self.board)
        with patch.object(supervisor, "invoke") as invoke:
            with self.assertRaises(core.GateError):
                supervisor.run_phase(self.args())
            invoke.assert_not_called()

    def test_scope_and_contract_changes_invalidate_approval(self):
        (self.root / "scope.md").write_text("Changed", encoding="utf-8")
        with self.assertRaises(core.GateError):
            core.check_approval(self.root, self.phase)
        (self.root / "scope.md").write_text("Approved test fixture scope", encoding="utf-8")
        self.phase["contract"]["requirements"].append("R2")
        with self.assertRaises(core.GateError):
            core.check_approval(self.root, self.phase)

    def test_explicit_revision_records_prior_approval_and_preserves_branch(self):
        original = copy.deepcopy(self.phase["approval"])
        original_contract = copy.deepcopy(self.phase["contract"])
        next_contract = {**self.contract, "requirements": ["R1", "R2"]}
        (self.root / "scope.md").write_text("Explicitly approved revised scope", encoding="utf-8")
        core.revise_approval(self.root, self.board, "mvp", "explicit revision fixture", next_contract)
        self.assertEqual(self.phase["approval_history"], [{"approval": original, "contract": original_contract}])
        self.assertEqual(self.phase["approval"]["development_branch"], "development/test")
        self.assertEqual(self.phase["approval"]["revision"], 2)
        self.assertEqual(self.phase["contract"], next_contract)
        core.check_approval(self.root, self.phase)

    def test_revision_requires_an_existing_approved_phase(self):
        self.phase["approval"]["status"] = "pending"
        with self.assertRaises(core.GateError):
            core.revise_approval(self.root, self.board, "mvp", "no approval", self.contract)

    def test_empty_contract_and_protected_branch_rejected(self):
        with self.assertRaises(core.GateError):
            core.validate_contract({"requirements": [], "checks": {}, "required_phase_checks": []})
        board = core.initialize(self.root, "second", "scope.md")
        with self.assertRaises(core.GateError):
            core.approve(self.root, board, "second", "main", "fixture", self.contract)

    def test_transitions_dependencies_and_lead_cannot_set_done(self):
        core.upsert_task(self.root, self.board, "mvp", self.task)
        for state in ["ready", "in_progress", "testing", "review"]:
            task = copy.deepcopy(self.phase["tasks"][0])
            task["status"] = state
            core.upsert_task(self.root, self.board, "mvp", task)
        task = copy.deepcopy(task)
        task["status"] = "done"
        with self.assertRaises(core.GateError):
            core.upsert_task(self.root, self.board, "mvp", task)
        child = {**self.task, "id": "T2", "dependencies": ["T1"]}
        core.upsert_task(self.root, self.board, "mvp", child)
        child["status"] = "ready"
        with self.assertRaises(core.GateError):
            core.upsert_task(self.root, self.board, "mvp", child)

    def test_dependency_cycle_rejected(self):
        self.phase["tasks"] = [self.task, {**self.task, "id": "T2", "dependencies": ["T1"]}]
        self.task["dependencies"] = ["T2"]
        with self.assertRaises(core.GateError):
            core.validate_tasks(self.phase)

    def test_ready_order(self):
        self.phase["tasks"] = [self.task, {**self.task, "id": "T2", "priority": 0}]
        self.assertEqual([t["id"] for t in core.ready_tasks(self.phase)], ["T2", "T1"])

    def test_os_lock_blocks_overlap_and_releases(self):
        with core.WorkspaceLock(self.root):
            with self.assertRaises(core.GateError):
                with core.WorkspaceLock(self.root):
                    pass
        with core.WorkspaceLock(self.root):
            pass

    def test_missing_stale_and_high_findings_block(self):
        current = self.reports()
        core.quality_evidence(self.root, self.task, current)
        with self.assertRaises(core.GateError):
            core.quality_evidence(self.root, self.task, {**current, "head": "changed"})
        review = self.root / self.task["evidence"]["review_report"]
        value = json.loads(review.read_text())
        value["findings"] = [{"priority": "P1", "resolved": False}]
        core.atomic_json(review, value)
        with self.assertRaises(core.GateError):
            core.quality_evidence(self.root, self.task, current)

    def test_acceptance_cannot_omit_criterion(self):
        current = self.reports()
        path = self.root / self.task["evidence"]["acceptance_report"]
        report = json.loads(path.read_text())
        report["criteria"] = []
        core.atomic_json(path, report)
        with self.assertRaises(core.GateError):
            core.quality_evidence(self.root, self.task, current)

    def test_actual_check_execution_and_failure(self):
        import time
        results = supervisor.execute_checks(self.root, self.phase, ["TEST"], self.root / ".autonomy/checks", time.monotonic() + 10)
        self.assertEqual(results[0]["returncode"], 0)
        self.phase["contract"]["checks"]["TEST"] = [sys.executable, "-c", "raise SystemExit(1)"]
        with self.assertRaises(core.GateError):
            supervisor.execute_checks(self.root, self.phase, ["TEST"], self.root / ".autonomy/checks", time.monotonic() + 10)

    def test_timeout_stops_spawned_process(self):
        result = supervisor.invoke([sys.executable, "-c", "import time;time.sleep(10)"], self.root, self.root / ".autonomy/timeout.log", .2)
        self.assertTrue(result["timed_out"])
        self.assertNotEqual(result["returncode"], 0)

    def test_defect_retry_is_bounded(self):
        self.phase["tasks"] = [self.task]
        supervisor.record_failure(self.phase, self.task, "fixture failure")
        defect = self.phase["tasks"][1]
        for _ in range(3):
            supervisor.record_failure(self.phase, defect, "same failure")
        self.assertEqual(len(self.phase["tasks"]), 2)
        self.assertEqual(defect["status"], "blocked")
        self.assertTrue(defect["needs_different_diagnosis"])

    def test_defect_id_collision_preserves_unrelated_task(self):
        unrelated = {**self.task, "id": "T1_FIX", "description": "Unrelated original task"}
        self.phase["tasks"] = [self.task, unrelated]
        supervisor.record_failure(self.phase, self.task, "fixture failure")
        self.assertEqual(unrelated["status"], "backlog")
        self.assertEqual(self.task["blocked_by"], "T1_FIX_2")
        self.assertEqual(self.phase["tasks"][2]["parent_task"], "T1")

    def test_no_progress_stops_and_resumes_exact_session(self):
        result, calls = self.run_fake(["continue"])
        self.assertEqual(result, 2)
        self.assertEqual(len(calls), 2)
        self.assertIn("fixture-session", calls[1])
        self.assertNotIn("--last", calls[1])

    def test_approval_request_stops_without_retry(self):
        result, calls = self.run_fake(["needs_approval"])
        self.assertEqual(result, 2)
        self.assertEqual(len(calls), 1)
        self.assertEqual(core.phase_of(core.read_board(self.root), "mvp")["execution_status"], "needs_approval")

    def test_false_completion_rejected(self):
        result, calls = self.run_fake(["complete"])
        self.assertEqual(result, 2)
        self.assertNotEqual(core.phase_of(core.read_board(self.root), "mvp")["execution_status"], "complete")

    def test_done_without_supervisor_receipt_rejected(self):
        self.task["status"] = "done"
        self.phase["tasks"] = [self.task]
        core.persist(self.root, self.board)
        with self.assertRaises(core.GateError):
            self.run_fake(["continue"])

    def test_complete_without_supervisor_phase_receipt_rejected(self):
        self.phase["execution_status"] = "complete"
        self.phase["verification"] = {"snapshot": {"head": "fake", "source_sha256": "fake"}}
        core.persist(self.root, self.board)
        with self.assertRaisesRegex(core.GateError, "supervisor receipt"):
            self.run_fake(["continue"])

    def test_token_guard_before_model(self):
        with self.assertRaises(core.GateError):
            self.run_fake(["continue"], max_tokens=100)

    def test_cost_guard_before_model(self):
        with self.assertRaises(core.GateError):
            self.run_fake(["continue"], max_cost=1.0)

    def test_three_attempts_require_different_diagnosis(self):
        task = {**self.task, "status": "blocked", "retry_count": 3, "needs_different_diagnosis": True}
        self.phase["tasks"] = [task]
        resumed = {**task, "status": "ready"}
        with self.assertRaises(core.GateError):
            core.upsert_task(self.root, self.board, "mvp", resumed)
        path = ".autonomy/diagnosis.json"
        core.atomic_json(self.root / path, {"kind": "diagnosis", "task_id": "T1", "role": "architect",
                                         "retry_count": 3, "new_approach": "Fixture different diagnosis"})
        resumed["diagnosis_report"] = path
        core.upsert_task(self.root, self.board, "mvp", resumed)
        self.assertFalse(self.phase["tasks"][0]["needs_different_diagnosis"])

    def test_crash_charges_reserved_slice(self):
        state = {"phase": "mvp", "session_id": "old-session", "budget": {"seconds": 0, "launches": 1, "reported_parent_tokens": 0},
                 "verified_tasks": {}, "failures": 0, "no_progress": 0, "active_run": {"reserved_seconds": 61}}
        core.atomic_json(self.root / ".autonomy/state/mvp.json", state)
        result, calls = self.run_fake(["continue"], runtime_seconds=60)
        self.assertEqual(calls, [])
        self.assertEqual(result, 2)

    def test_verification_and_phase_complete_end_to_end(self):
        def git(*args):
            subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)
        git("init", "-b", "development/test")
        git("config", "user.name", "Fixture")
        git("config", "user.email", "fixture@example.invalid")
        (self.root / ".gitignore").write_text(".autonomy/\n")
        (self.root / "release.md").write_text("Fixture release, no actual product built")
        git("add", ".")
        git("commit", "-m", "Fixture")
        self.task["status"] = "review"
        self.reports(current=core.snapshot(self.root))
        self.phase["tasks"] = [self.task]
        core.persist(self.root, self.board)
        def mutate(index):
            if index == 1:
                board = core.read_board(self.root)
                phase = core.phase_of(board, "mvp")
                core.atomic_json(self.root / ".autonomy/final.json", {"kind": "phase_review", "phase": "mvp",
                    "role": "code_reviewer", "status": "passed", "snapshot": core.snapshot(self.root),
                    "task_ids": ["T1"], "findings": []})
                core.atomic_json(self.root / ".autonomy/final-qa.json", {"kind": "phase_qa", "phase": "mvp",
                    "role": "qa_engineer", "status": "passed", "snapshot": core.snapshot(self.root),
                    "requirements": [{"id": "R1", "passed": True, "evidence": "Fixture verification"}],
                    "task_acceptance": [{"task_id": "T1", "criteria": [{"criterion": "Fixture works", "passed": True, "evidence": "Fixture verification"}]}]})
                phase["evidence"] = {"review_report": ".autonomy/final.json", "qa_report": ".autonomy/final-qa.json", "release_candidate": "release.md"}
                core.persist(self.root, board)
        result, calls = self.run_fake(["continue", "complete"], mutate=mutate)
        self.assertEqual(result, 0)
        phase = core.phase_of(core.read_board(self.root), "mvp")
        self.assertEqual(phase["execution_status"], "complete")
        self.assertEqual(phase["tasks"][0]["status"], "done")
        self.assertTrue(phase["verification"]["checks"])
        repeated, repeated_calls = self.run_fake(["continue"])
        self.assertEqual(repeated, 0)
        self.assertEqual(repeated_calls, [])
        qa_path = self.root / phase["tasks"][0]["evidence"]["qa_report"]
        qa_path.write_text(qa_path.read_text() + " ")
        with self.assertRaisesRegex(core.GateError, "task report changed"):
            self.run_fake(["continue"])

    def test_receipt_before_board_recovers_after_checkpoint_crash(self):
        def git(*args):
            subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)
        git("init", "-b", "development/test")
        git("config", "user.name", "Fixture")
        git("config", "user.email", "fixture@example.invalid")
        (self.root / ".gitignore").write_text(".autonomy/\n")
        git("add", ".")
        git("commit", "-m", "Fixture")
        self.task["status"] = "review"
        self.reports(current=core.snapshot(self.root))
        self.phase["tasks"] = [self.task]
        core.persist(self.root, self.board)
        real_persist = supervisor.persist
        def fail_after_receipt(root, board):
            if core.phase_of(board, "mvp")["tasks"][0]["status"] == "done":
                raise OSError("fixture checkpoint crash")
            real_persist(root, board)
        with patch.object(supervisor, "persist", side_effect=fail_after_receipt):
            with self.assertRaises(OSError):
                self.run_fake(["continue"], max_launches=1)
        self.assertEqual(core.phase_of(core.read_board(self.root), "mvp")["tasks"][0]["status"], "review")
        state = json.loads((self.root / ".autonomy/state/mvp.json").read_text())
        self.assertIn("T1", state["verified_tasks"])
        self.run_fake(["continue"], max_launches=2)
        self.assertEqual(core.phase_of(core.read_board(self.root), "mvp")["tasks"][0]["status"], "done")

    def test_fast_process_exit_preserves_session_id(self):
        script = "import json; print(json.dumps(dict(type=\"thread.started\",thread_id=\"fast-session\")))"
        result = supervisor.invoke([sys.executable, "-c", script], self.root, self.root / ".autonomy/fast.log", 5)
        self.assertEqual(result["session_id"], "fast-session")

    def test_budget_expiry_does_not_create_defect(self):
        import time
        self.phase["contract"]["checks"]["TEST"] = [sys.executable, "-c", "import time;time.sleep(10)"]
        with self.assertRaises(supervisor.BudgetExpired):
            supervisor.execute_checks(self.root, self.phase, ["TEST"], self.root / ".autonomy/checks", time.monotonic() + .2)
        self.assertEqual(self.phase["tasks"], [])

    @unittest.skipUnless(sys.platform == "win32", "Windows process Job regression")
    def test_parent_crash_kills_contained_child(self):
        import ctypes
        import time
        child_file = self.root / "child.pid"
        child = f"import os,time,pathlib;pathlib.Path({str(child_file)!r}).write_text(str(os.getpid()));time.sleep(30)"
        module_path = str(Path(supervisor.__file__).parent)
        parent_script = (f"import sys,pathlib;sys.path.insert(0,{module_path!r});import supervisor;"
                         f"supervisor.invoke([{sys.executable!r},'-c',{child!r}],pathlib.Path({str(self.root)!r}),"
                         f"pathlib.Path({str(self.root / '.autonomy/crash.log')!r}),30)")
        parent = subprocess.Popen([sys.executable, "-c", parent_script], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            until = time.monotonic() + 5
            while not child_file.exists() and time.monotonic() < until:
                time.sleep(.05)
            self.assertTrue(child_file.exists())
            pid = int(child_file.read_text())
            api = ctypes.WinDLL("kernel32", use_last_error=True)
            api.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
            api.OpenProcess.restype = ctypes.c_void_p
            api.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
            api.CloseHandle.argtypes = [ctypes.c_void_p]
            handle = api.OpenProcess(0x00100000, False, pid)
            self.assertTrue(handle)
            parent.kill()
            parent.wait(timeout=5)
            try:
                self.assertEqual(api.WaitForSingleObject(handle, 3000), 0)
            finally:
                api.CloseHandle(handle)
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait(timeout=5)
            parent.stderr.close()

    def test_budget_persists_between_invocations(self):
        result, calls = self.run_fake(["continue"], max_launches=1)
        self.assertEqual(len(calls), 1)
        result, calls = self.run_fake(["continue"], max_launches=1)
        self.assertEqual(len(calls), 0)
        self.assertEqual(core.phase_of(core.read_board(self.root), "mvp")["execution_status"], "budget_exhausted")

    def test_coverage_requires_every_approved_requirement(self):
        self.task["status"] = "done"
        self.phase["tasks"] = [self.task]
        self.phase["contract"]["requirements"].append("R2")
        with self.assertRaises(core.GateError):
            core.phase_coverage(self.phase)

    def test_real_git_snapshot_and_operational_dirty_files(self):
        def run(*args):
            subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)
        run("init", "-b", "development/test")
        run("config", "user.name", "Fixture")
        run("config", "user.email", "fixture@example.invalid")
        (self.root / ".gitignore").write_text(".autonomy/\n")
        run("add", ".")
        run("commit", "-m", "Fixture")
        first = core.snapshot(self.root)
        core.persist(self.root, self.board)
        self.assertEqual(first, core.snapshot(self.root))
        core.integrated(self.root, self.phase)
        (self.root / "scope.md").write_text("Dirty scope")
        with self.assertRaises(core.GateError):
            core.integrated(self.root, self.phase)
        self.assertNotEqual(first, core.snapshot(self.root))


if __name__ == "__main__":
    unittest.main()
