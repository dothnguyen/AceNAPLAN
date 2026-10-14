"""Synthetic context regressions; fixtures never constitute pilot evidence."""

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from evidence import EvidenceError  # noqa: E402
from gate_context import EVIDENCE_ROOT, GATE_CHECKS, core, validate_gate_context  # noqa: E402
import pilot_gate  # noqa: E402


class GateContextTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "-q")
        (self.root / ".gitignore").write_text(".autonomy/\n", encoding="utf-8")
        scope = self.root / "docs/product/pilot.md"
        scope.parent.mkdir(parents=True)
        scope.write_text("approved synthetic scope\n", encoding="utf-8")
        self.git("add", ".gitignore", "docs/product/pilot.md")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-qm", "fixture")
        branch = self.git("branch", "--show-current").stdout.strip()
        checks = {check_id: ["python", "scripts/verification/pilot_gate.py", "--gate", name]
                  for name, check_id in GATE_CHECKS.items()}
        self.contract = {"requirements": ["PILOT-04"], "checks": checks,
                         "required_phase_checks": list(checks)}
        self.phase = {"scope_path": "docs/product/pilot.md",
                      "approval": {"status": "approved", "scope_sha256": core.scope_digest(scope),
                                   "contract_sha256": core.digest(self.contract),
                                   "development_branch": branch},
                      "contract": self.contract}
        self.board_path = self.root / "docs/development/task-board.json"
        self.write_board()
        self.git("add", "docs/development/task-board.json")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "-qm", "board fixture")
        evidence = self.root / EVIDENCE_ROOT
        (evidence / "gates").mkdir(parents=True)
        self.artifact = evidence / "run.log"
        self.artifact.write_bytes(b"synthetic output")
        self.snapshot = core.snapshot(self.root)
        self.envelope = {"schema_version": 1, "gate_id": "PILOT-CONTENT",
                         "status": "passed", "observed_at": "2026-10-13T06:00:00Z",
                         "producer": {"id": "fixture", "type": "test"},
                         "snapshot": self.snapshot, "observations": {"synthetic": True},
                         "artifacts": [{"path": ".autonomy/evidence/pilot/run.log",
                                        "sha256": hashlib.sha256(self.artifact.read_bytes()).hexdigest()}]}
        self.envelope_path = evidence / "gates/content.json"
        self.write_envelope()

    def git(self, *args):
        result = subprocess.run(["git", "-C", str(self.root), *args],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def write_board(self):
        self.board_path.parent.mkdir(parents=True, exist_ok=True)
        self.board_path.write_text(json.dumps({"schema_version": 1,
                                               "phases": {"pilot": self.phase}}), encoding="utf-8")

    def write_envelope(self):
        self.envelope_path.write_text(json.dumps(self.envelope), encoding="utf-8")

    def test_fixed_valid_envelope_is_integrity_only(self):
        self.assertIsNone(validate_gate_context("content", workspace=self.root))
        for gate in GATE_CHECKS:
            if gate != "content":
                with self.subTest(gate=gate), self.assertRaises(EvidenceError):
                    validate_gate_context(gate, workspace=self.root)

    def test_cli_stays_pending_after_integrity_success(self):
        with patch.object(pilot_gate, "validate_gate_context", return_value=None):
            self.assertEqual(pilot_gate.main(["--gate", "content"]), 1)

    def test_missing_stale_tampered_and_mismatched_evidence(self):
        original = copy.deepcopy(self.envelope)
        for change in (
            lambda e: e["snapshot"].update(source_sha256="f" * 64),
            lambda e: e.update(gate_id="PILOT-BROWSER-FLOWS"),
            lambda e: e["artifacts"][0].update(sha256="0" * 64),
            lambda e: e["artifacts"][0].update(path="../run.log"),
        ):
            self.envelope = copy.deepcopy(original)
            change(self.envelope)
            self.write_envelope()
            with self.assertRaises(EvidenceError):
                validate_gate_context("content", workspace=self.root)
        self.envelope_path.unlink()
        with self.assertRaises(EvidenceError):
            validate_gate_context("content", workspace=self.root)

    def test_approved_contract_and_clean_branch_are_required(self):
        self.contract["checks"]["PILOT-CONTENT"][-1] = "browser"
        self.phase["approval"]["contract_sha256"] = core.digest(self.contract)
        self.write_board()
        with self.assertRaises(EvidenceError):
            validate_gate_context("content", workspace=self.root)
        self.contract["checks"]["PILOT-CONTENT"][-1] = "content"
        self.phase["approval"]["contract_sha256"] = core.digest(self.contract)
        self.write_board()
        (self.root / "dirty.txt").write_text("changed", encoding="utf-8")
        with self.assertRaises(core.GateError):
            validate_gate_context("content", workspace=self.root)

    def test_unknown_gate_and_duplicate_json_field_rejected(self):
        with self.assertRaises(EvidenceError):
            validate_gate_context("../content", workspace=self.root)
        self.envelope_path.write_text(self.envelope_path.read_text(encoding="utf-8")[:-1]
                                      + ',"status":"passed"}', encoding="utf-8")
        with self.assertRaises(EvidenceError):
            validate_gate_context("content", workspace=self.root)


if __name__ == "__main__":
    unittest.main()
