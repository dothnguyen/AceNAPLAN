"""Synthetic CLI regressions; no test fixture is pilot evidence."""

import subprocess
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "pilot_gate.py"
OPAQUE_GATES = (
    "content",
    "browser",
    "android_integration",
    "educator",
    "physical_phone",
    "physical_tablet",
    "release_candidate",
)


class PilotGateCliTests(unittest.TestCase):
    def run_gate(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_each_frozen_gate_fails_without_semantic_evidence(self):
        for gate in OPAQUE_GATES:
            with self.subTest(gate=gate):
                result = self.run_gate("--gate", gate)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("semantic validator", result.stderr)
                self.assertNotIn("passed", result.stdout.lower())

    def test_missing_and_malformed_gate_arguments_fail(self):
        for args in ((), ("--gate",), ("--gate=",), ("--gate", "CONTENT")):
            with self.subTest(args=args):
                self.assertNotEqual(self.run_gate(*args).returncode, 0)

    def test_unsupported_gate_and_evidence_input_fail(self):
        for args in (
            ("--gate", "unknown"),
            ("--gate", "PILOT-CONTENT"),
            ("--gate", "content", "--evidence", '{"status":"passed"}'),
            ("--gate", "content", "--gate", "browser"),
        ):
            with self.subTest(args=args):
                result = self.run_gate(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("semantic validator", result.stderr)


if __name__ == "__main__":
    unittest.main()
