"""Synthetic platform claims; these are never pilot execution evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from platform_claims import (  # noqa: E402
    PlatformClaimError,
    validate_physical_pair,
    validate_platform_observation,
)


SNAPSHOT = {"head": "a" * 40, "source_sha256": "b" * 64}
ARTIFACTS = {
    "run.log": "1" * 64,
    "app.bin": "2" * 64,
    "practice.log": "3" * 64,
    "feedback.log": "4" * 64,
    "summary.log": "5" * 64,
    "sqlite_save_restart.log": "6" * 64,
    "migration.log": "7" * 64,
    "offline_practice.log": "8" * 64,
    "audio.log": "9" * 64,
    "accessibility.log": "c" * 64,
}
FLOWS = {
    "browser": ("practice", "feedback", "summary"),
    "android_integration": ("sqlite_save_restart", "migration", "offline_practice"),
    "physical_phone": ("offline_practice", "audio", "accessibility"),
    "physical_tablet": ("offline_practice", "audio", "accessibility"),
}


def claim(gate):
    platform = "web" if gate == "browser" else "android"
    kind = "browser" if gate == "browser" else ("emulator" if gate == "android_integration" else "physical")
    form = "browser" if gate == "browser" else ("tablet" if gate == "physical_tablet" else "phone")
    return {
        "run": {"id": f"run-{gate}-001", "started_at": "2026-10-15T01:00:00Z",
                "ended_at": "2026-10-15T01:01:00Z", "command": "synthetic fixture",
                "build_id": "synthetic-build", "target_device_id": f"synthetic-{gate}",
                "log_artifact": "run.log"},
        "source": copy.deepcopy(SNAPSHOT),
        "build": {"id": "synthetic-build", "sha256": "2" * 64, "artifact": "app.bin"},
        "target": {"platform": platform, "kind": kind,
                   "device_id": f"synthetic-{gate}", "form_factor": form},
        "adapter": "memory" if gate == "browser" else "sqlite",
        "flows": [{"name": name, "outcome": "passed", "artifact": f"{name}.log"}
                  for name in FLOWS[gate]],
    }


class PlatformClaimTests(unittest.TestCase):
    def check(self, gate, item):
        validate_platform_observation(gate, item, expected_snapshot=SNAPSHOT,
                                      artifact_digests=ARTIFACTS)

    def test_valid_synthetic_structures(self):
        for gate in FLOWS:
            with self.subTest(gate=gate):
                self.check(gate, claim(gate))

    def test_build_only_is_not_browser_flow(self):
        item = claim("browser")
        item["flows"] = []
        with self.assertRaises(PlatformClaimError):
            self.check("browser", item)
        item["flows"] = [{"name": "build", "outcome": "passed", "artifact": "app.bin"}]
        with self.assertRaises(PlatformClaimError):
            self.check("browser", item)

    def test_web_and_memory_cannot_claim_android_sqlite(self):
        for change in ({"platform": "web"}, {"kind": "browser"}, {"adapter": "memory"}):
            with self.subTest(change=change):
                item = claim("android_integration")
                if "adapter" in change:
                    item["adapter"] = change["adapter"]
                else:
                    item["target"].update(change)
                with self.assertRaises(PlatformClaimError):
                    self.check("android_integration", item)

    def test_emulator_cannot_claim_physical_device(self):
        for gate in ("physical_phone", "physical_tablet"):
            item = claim(gate)
            item["target"]["kind"] = "emulator"
            with self.subTest(gate=gate), self.assertRaises(PlatformClaimError):
                self.check(gate, item)

    def test_distinct_physical_targets_and_runs(self):
        phone, tablet = claim("physical_phone"), claim("physical_tablet")
        self.check("physical_phone", phone)
        self.check("physical_tablet", tablet)
        validate_physical_pair(phone, tablet)
        tablet["target"]["device_id"] = phone["target"]["device_id"]
        with self.assertRaises(PlatformClaimError):
            validate_physical_pair(phone, tablet)
        tablet["target"]["device_id"] = "other-device"
        tablet["run"]["id"] = phone["run"]["id"]
        with self.assertRaises(PlatformClaimError):
            validate_physical_pair(phone, tablet)

    def test_missing_failed_or_unreferenced_flow_rejected(self):
        for mutation in ("missing", "failed", "unreferenced", "duplicate"):
            item = claim("android_integration")
            if mutation == "missing":
                item["flows"].pop()
            elif mutation == "failed":
                item["flows"][0]["outcome"] = "failed"
            elif mutation == "unreferenced":
                item["flows"][0]["artifact"] = "unlisted.log"
            else:
                item["flows"].append(copy.deepcopy(item["flows"][0]))
            with self.subTest(mutation=mutation), self.assertRaises(PlatformClaimError):
                self.check("android_integration", item)

    def test_stale_source_or_unbound_build_rejected(self):
        item = claim("browser")
        item["source"]["head"] = "d" * 40
        with self.assertRaises(PlatformClaimError):
            self.check("browser", item)
        item = claim("browser")
        item["build"]["sha256"] = "e" * 64
        with self.assertRaises(PlatformClaimError):
            self.check("browser", item)
        item = claim("browser")
        item["run"]["build_id"] = "different-build"
        with self.assertRaises(PlatformClaimError):
            self.check("browser", item)

    def test_run_identity_and_artifacts_required(self):
        for mutation in ("short-id", "zero-duration", "missing-log", "missing-build"):
            item = claim("browser")
            if mutation == "short-id":
                item["run"]["id"] = "x"
            elif mutation == "zero-duration":
                item["run"]["ended_at"] = item["run"]["started_at"]
            elif mutation == "missing-log":
                item["run"]["log_artifact"] = "missing.log"
            else:
                item["build"]["artifact"] = "missing.bin"
            with self.subTest(mutation=mutation), self.assertRaises(PlatformClaimError):
                self.check("browser", item)
        item = claim("browser")
        item["run"]["target_device_id"] = "other-device"
        with self.assertRaises(PlatformClaimError):
            self.check("browser", item)


if __name__ == "__main__":
    unittest.main()
