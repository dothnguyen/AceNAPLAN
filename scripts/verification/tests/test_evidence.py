"""Synthetic fixture tests; these records are never release evidence."""

import copy
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from evidence import EvidenceError, validate_envelope  # noqa: E402


class EnvelopeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        evidence_dir = self.root / "evidence"
        evidence_dir.mkdir()
        self.artifact = evidence_dir / "run.log"
        self.artifact.write_bytes(b"synthetic test observation\n")
        self.snapshot = {"head": "a" * 40, "source_sha256": "b" * 64}
        self.envelope = {
            "schema_version": 1,
            "gate_id": "PILOT-CONTENT",
            "status": "passed",
            "observed_at": "2026-10-13T06:00:00Z",
            "producer": {"id": "synthetic-test", "type": "test"},
            "snapshot": self.snapshot.copy(),
            "observations": {"test_fixture": True},
            "artifacts": [{"path": "evidence/run.log", "sha256": hashlib.sha256(
                self.artifact.read_bytes()).hexdigest()}],
        }

    def validate(self, envelope=None, **overrides):
        options = {"expected_snapshot": self.snapshot, "workspace": self.root,
                   "allowed_gates": {"PILOT-CONTENT"},
                   "artifact_roots": [self.root / "evidence"]}
        options.update(overrides)
        return validate_envelope(self.envelope if envelope is None else envelope, **options)

    def reject(self, mutate):
        envelope = copy.deepcopy(self.envelope)
        mutate(envelope)
        with self.assertRaises(EvidenceError):
            self.validate(envelope)

    def test_valid_fixture_is_only_an_integrity_result(self):
        self.assertIsNone(self.validate())
        with self.assertRaises(EvidenceError):
            self.validate(artifact_roots=[])

    def test_missing_and_malformed_fields(self):
        self.reject(lambda e: e.pop("observed_at"))
        self.reject(lambda e: e.update(schema_version=True))
        self.reject(lambda e: e.update(schema_version=2))
        self.reject(lambda e: e.update(status="failed"))
        self.reject(lambda e: e.update(observations={}))
        self.reject(lambda e: e.update(observed_at="2026-10-13"))
        self.reject(lambda e: e.update(producer={"id": "x"}))
        self.reject(lambda e: e.update(gate_id="PILOT-UNKNOWN"))
        self.reject(lambda e: e.update(artifacts=[]))
        self.reject(lambda e: e["artifacts"][0].pop("sha256"))

    def test_stale_snapshot_head_and_digest(self):
        self.reject(lambda e: e["snapshot"].update(head="c" * 40))
        self.reject(lambda e: e["snapshot"].update(source_sha256="c" * 64))
        self.reject(lambda e: e["snapshot"].update(head="short"))

    def test_unsafe_paths(self):
        for path in ("../outside", "evidence/../run.log", "/tmp/run.log",
                     "C:/outside/run.log", "evidence\\run.log"):
            with self.subTest(path=path):
                self.reject(lambda e: e["artifacts"][0].update(path=path))
        outside = self.root.parent / (self.root.name + "-outside")
        outside.write_bytes(b"outside")
        self.addCleanup(outside.unlink)
        link = self.root / "evidence" / "escape"
        try:
            link.symlink_to(outside)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable in this environment")
        self.reject(lambda e: e["artifacts"][0].update(path="evidence/escape"))

    def test_missing_tampered_and_duplicate_artifact(self):
        self.reject(lambda e: e["artifacts"][0].update(path="evidence/missing.log"))
        self.reject(lambda e: e["artifacts"].append(e["artifacts"][0].copy()))
        self.artifact.write_bytes(b"tampered")
        with self.assertRaises(EvidenceError):
            self.validate()


if __name__ == "__main__":
    unittest.main()
