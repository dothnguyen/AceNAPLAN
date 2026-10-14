# Pilot evidence envelope, schema 1

`scripts/verification/evidence.py` validates the structure and integrity of a local evidence envelope. A trusted runner supplies the expected source snapshot, approved gate IDs, workspace and permitted artifact roots. These inputs must not be copied from the envelope under test. The validator raises `EvidenceError` on failure and returns `None` on structural and integrity success.

```json
{
  "schema_version": 1,
  "gate_id": "PILOT-CONTENT",
  "status": "passed",
  "observed_at": "2026-10-13T06:00:00Z",
  "producer": {"id": "actual-producer-id", "type": "tool"},
  "snapshot": {
    "head": "0123456789abcdef0123456789abcdef01234567",
    "source_sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  },
  "observations": {"actual_check": "Describe what ran and what was seen"},
  "artifacts": [{
    "path": ".autonomy/evidence/pilot/example/check.log",
    "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }]
}
```

All fields are required; extra fields are rejected. `schema_version` is exactly integer 1. `gate_id` must be an approved `PILOT-...` ID supplied by the runner. `status` is exactly `passed`; an unsuccessful run must fail validation. `observed_at` is an ISO 8601 timestamp with timezone. `producer.id` is nonempty and `producer.type` is one of `tool`, `human`, `device`, `reviewer`, or `test`. `snapshot.head` is a lowercase 40-character Git commit ID and `snapshot.source_sha256` a lowercase SHA-256; both must match the trusted current snapshot exactly. `observations` is a nonempty JSON object describing actual work. `artifacts` is a nonempty list of unique workspace-relative paths and lowercase SHA-256 digests. Paths with traversal, drives, absolute forms, backslashes, or symlink resolution outside permitted roots fail. Each artifact must be a readable regular file with matching content digest. Callers may narrow the permitted roots, which must themselves be inside the workspace.

Envelope validity only proves that the record has the expected shape and that referenced local bytes match their declared hashes at validation time. It does not authenticate the producer or prove that observations are true. It cannot by itself satisfy content, educator, browser, native-device, or release gates. Each gate needs its own semantic validator and real evidence; an unimplemented gate must fail. The synthetic regression fixtures are tests, not pilot or release evidence.

## Opaque pilot gate CLI

The frozen check contract invokes `python scripts/verification/pilot_gate.py --gate <name>`. The only accepted names are `content`, `browser`, `android_integration`, `educator`, `physical_phone`, `physical_tablet`, and `release_candidate`. Missing, malformed, or unknown names fail. The current CLI deliberately returns nonzero for every recognized name because no gate-specific semantic validator is installed. It accepts no evidence path or envelope argument. A valid envelope cannot make a gate pass, and the CLI's existence is not evidence of a successful pilot check.

The parent verification task must add genuine, source-snapshot-bound checks before any opaque gate may return success: reviewed question/content and asset validation for `content`; executed browser flows for `browser`; real Android SQLite/import/restart integration for `android_integration`; an authenticated educational sign-off for `educator`; executed offline, audio and accessibility checks on a physical phone and tablet for `physical_phone` and `physical_tablet`; and complete, current build, check, review and release-readiness evidence for `release_candidate`. Each validator must use trusted runner inputs for the expected snapshot and permitted evidence roots, verify the envelope with `evidence.py` where applicable, and independently verify the gate's actual outcome. Synthetic regression fixtures are never accepted as pilot evidence.
