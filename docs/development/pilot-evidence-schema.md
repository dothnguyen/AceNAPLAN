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

The frozen check contract invokes `python scripts/verification/pilot_gate.py --gate <name>`. The only accepted names are `content`, `browser`, `android_integration`, `educator`, `physical_phone`, `physical_tablet`, and `release_candidate`. Missing, malformed, or unknown names fail. The current CLI returns nonzero for every recognized name while its production semantic validators are unavailable. It accepts no evidence path or envelope argument. A valid envelope cannot make a gate pass, and the CLI's existence is not evidence of a successful pilot check.

The parent verification task must add genuine, source-snapshot-bound checks before any opaque gate may return success: reviewed question/content and asset validation for `content`; executed browser flows for `browser`; real Android SQLite/import/restart integration for `android_integration`; an authenticated educational sign-off for `educator`; executed offline, audio and accessibility checks on a physical phone and tablet for `physical_phone` and `physical_tablet`; and complete, current build, check, review and release-readiness evidence for `release_candidate`. Each validator must use trusted runner inputs for the expected snapshot and permitted evidence roots, verify the envelope with `evidence.py` where applicable, and independently verify the gate's actual outcome. Synthetic regression fixtures are never accepted as pilot evidence.

## Fixed gate context

The CLI maps each approved name to one check ID and one fixed envelope path under `.autonomy/evidence/pilot/gates/`:

| Gate name | Approved check ID | Envelope |
| --- | --- | --- |
| `content` | `PILOT-CONTENT` | `gates/content.json` |
| `browser` | `PILOT-BROWSER-FLOWS` | `gates/browser.json` |
| `android_integration` | `PILOT-ANDROID-INTEGRATION` | `gates/android_integration.json` |
| `educator` | `PILOT-EDUCATOR` | `gates/educator.json` |
| `physical_phone` | `PILOT-PHYSICAL-PHONE` | `gates/physical_phone.json` |
| `physical_tablet` | `PILOT-PHYSICAL-TABLET` | `gates/physical_tablet.json` |
| `release_candidate` | `PILOT-RELEASE-CANDIDATE` | `gates/release_candidate.json` |

`gate_context.py` reads the approved pilot board and checks its scope and contract hashes, the frozen CLI commands, approved branch, and clean current Git source snapshot. It reads only the fixed envelope for the selected gate and confines artifact references to `.autonomy/evidence/pilot/`. Missing, stale, malformed, or tampered records fail. The CLI accepts no caller-selected path or root. Even when all integrity checks succeed, the gate remains nonzero until a separate semantic validator verifies the actual check outcome.

## Content reader boundary (PILOT-T11E)

After fixed context validation, `--gate content` calls `content_gate.py` with the runner's workspace and current source snapshot. The reader interface must extract exact bytes from the actual release package, bind the package to that snapshot, and return a bounded projection of the packaged catalogue, canonical question bytes, asset bytes, digests, and review records. The gate checks that package, question, and asset bytes match their declared digests, that the catalogue is release approved, that every item has a matching approved review, and that every referenced asset is present under its owning item. Audio assets also require matching approved audio reviews. It then requires a semantic adapter to run the full Dart release validator over those exact packaged records, including bank quotas, question rules, variation, audio format, and accessible alternatives, followed by an authentic educator sign-off verifier bound to the source snapshot.

No T12 release-bank container layout or extraction implementation is selected here. The production reader, semantic adapter, and sign-off verifier are unavailable, so `python scripts/verification/pilot_gate.py --gate content` remains nonzero even with a valid envelope. A future implementation must wire a real packaged bank, execute semantic validation, and establish authentic educator sign-off before claiming PILOT-CONTENT. Synthetic injected readers, validators, and sign-off in unit tests show rejection and orchestration behavior only; they cannot authenticate packaged content or reviews. Locally editable JSON and matching local hashes alone do not establish package provenance or human approval.

## Platform observation structure (PILOT-T11D)

`platform_claims.py` provides pure structural checks for `browser`, `android_integration`, `physical_phone`, and `physical_tablet` observations. A caller supplies the trusted current `expected_snapshot` and an artifact path-to-digest map only after validating the enclosing envelope and artifact bytes. The observation has exactly these fields:

```json
{
  "run": {
    "id": "unique-executed-run-id",
    "started_at": "2026-10-15T01:00:00Z",
    "ended_at": "2026-10-15T01:01:00Z",
    "command": "actual execution command or procedure",
    "build_id": "build-id",
    "target_device_id": "observed-device-id",
    "log_artifact": "relative/path/to/run.log"
  },
  "source": {"head": "40 lowercase hex characters", "source_sha256": "64 lowercase hex characters"},
  "build": {"id": "build-id", "sha256": "64 lowercase hex characters", "artifact": "relative/path/to/build"},
  "target": {"platform": "android", "kind": "physical", "device_id": "observed-device-id", "form_factor": "phone"},
  "adapter": "sqlite",
  "flows": [
    {"name": "offline_practice", "outcome": "passed", "artifact": "relative/path/to/flow.log"},
    {"name": "audio", "outcome": "passed", "artifact": "relative/path/to/audio.log"},
    {"name": "accessibility", "outcome": "passed", "artifact": "relative/path/to/accessibility.log"}
  ]
}
```

All fields are required and extras rejected. Run IDs need at least eight characters, timezone-aware start/end times must have positive elapsed time, and each run and flow references an envelope artifact. The run's build and target IDs must match the described build and target. Source must match the trusted current snapshot; build SHA-256 must match its envelope artifact digest. The caller must establish that the artifact is the executable actually run. A build command or build artifact alone is never a browser flow result.

| Gate | Required target and adapter | Required passed flows |
| --- | --- | --- |
| `browser` | `web` / `browser` / `browser` / `memory` | `practice`, `feedback`, `summary` |
| `android_integration` | `android` / `emulator` or `physical` / `phone` or `tablet` / `sqlite` | `sqlite_save_restart`, `migration`, `offline_practice` |
| `physical_phone` | `android` / `physical` / `phone` / `sqlite` | `offline_practice`, `audio`, `accessibility` |
| `physical_tablet` | `android` / `physical` / `tablet` / `sqlite` | `offline_practice`, `audio`, `accessibility` |

The four target values are platform, kind, form factor, and adapter. Flow names must match the gate's set exactly, with one passed result per flow and a referenced artifact for each. Physical phone and tablet observations also require distinct run IDs and device IDs through `validate_physical_pair`; the pair check follows individual validation. A locally editable JSON record, log or device ID cannot authenticate a human, prove hardware identity, or prove a flow was truly executed. A future gate implementation must independently verify run/build provenance, actual behavior and device identity. These synthetic schema regressions establish only rejection rules; `pilot_gate.py` still returns nonzero for every opaque gate.
