# Setup validation

Date: 2026-10-12 (Australia/Brisbane)

## Deterministic checks

- Python 3.11 `tomllib` parsed `.codex/config.toml` and all six role TOMLs: 7/7 passed. Assertions checked role names, non-empty descriptions/instructions, requested model/effort pairs, primary astra/high defaults, enabled agents, the three-subagent cap, resolvable registered files, and read-only reviewer sandbox.
- Desktop Codex `0.162.0-alpha.17.2` app-server started with `--strict-config`. Native `config/read` with this workspace as `cwd` returned the project layer, model `gpt-6-astra`, effort `high`, enabled agents, maximum concurrent spawned threads `3`, and all six role registrations with resolved absolute config-file paths. No schema/config error was returned.
- The successful native probe used an isolated temporary Codex home containing only this project's trust entry. No actual user/global config, credential file, cloud resource, application code, or existing PRD/design was changed. The local app-server was terminated after reading configuration; no model call was made by the probe.
- The desktop prompt renderer read the project AGENTS.md. This alone did not establish custom-role loading; the effective-config result above is the configuration evidence.

## Native delegation demonstration

Two bounded fresh-context native subagents ran concurrently, below the configured maximum of three:

| Delegate | Explicitly dispatched model/effort | Read-only deliverable | Result |
| --- | --- | --- | --- |
| architecture_smoke | gpt-6-astra / high | Inspect AGENTS.md, architect role, architecture status, and ADR 0001 for approved direction and pending decisions | Completed; no substantive contradictions or missing necessary decision boundaries |
| review_smoke | gpt-6-sol / high | Independently inspect role/config/workflow files for assignments, ownership, approvals, costs, and validation honesty | Completed; no actionable P0-P3 findings |

Both delegates adopted their role instructions, made no edits, spawned no further agents, and ran no application/platform tests. Lead consolidated their reports. No corrective implementation was needed.

## Limits and activation

The demonstration used native explicit model/effort overrides plus role instructions. It did not exercise a named custom-role spawn because this chat's spawn interface has no role selector. Native configuration loading verified registrations, while Python parsing verified role contents; full custom-role execution remains a new-session check. QA's requested gpt-5.6-terra/medium is catalog-supported and configured, but was not executed because the active spawn tool does not expose that model override. No silent substitution occurred.

The initial doctor checks loaded only defaults and are not counted as successful project configuration validation. A node-based app-server probe encountered filesystem restrictions; an approved local probe outside the sandbox used temporary state and succeeded. One initial stdin probe ended before returning its configuration response and was replaced with sequential request/response handling.

No project trust entry was found in the inspected real user config. A new desktop/CLI session must trust the workspace before relying on local settings; follow the client's trust flow if it reports disabled configuration. This setup leaves that global security setting unchanged. The older PATH CLI `0.137.0` failed the initial modern-setting probe; target the verified desktop runtime or separately verify/update the CLI.

There is no Flutter project or Git repository. Flutter, Flame, Firebase, SQLite, devices, browsers, synchronization, and runtime enforcement of the concurrency limit were not tested. Static cap verification and a two-agent demonstration do not prove behavior at the cap. Existing planning/design artifacts were preserved.

## Phase-parameterized orchestration upgrade

Implemented 2026-10-12 after the user authorized a reusable phase parameter, with future phase development commands deferred until scope is ready. The initial `mvp` phase remains pending with zero application tasks. The proposed scope, phase template, shared board/schema, progress record, native role instructions, and Python supervisor are installed. All original role model/effort assignments and the three-specialist cap are preserved.

Executed `python -m unittest discover -s scripts/autonomy/tests -q`: **32 tests passed**. The suite uses temporary fixture workspaces and mock Codex results; it makes no model or cloud calls. Real local subprocess and Git fixture checks exercised check success/failure, process timeout, Windows suspended-child Job containment and parent-crash cleanup, operational-file snapshot exclusions, and integrated-source gates. Mock-run checks exercised phase selection, approval/hash gates, legal task states, dependency cycles/order, missing and stale evidence, high review findings, defect ID collisions, three-attempt alternate diagnosis, false completion, phase completion receipts, tampered reports, exact-session resume, no-progress stops, persistent/crash-reserved budgets, and checkpoint receipt recovery. A complete fixture phase reran actual local verification commands and then returned unchanged completion without another mock model launch.

Python compilation passed for `core.py`, `board.py`, and `supervisor.py`; all orchestration JSON and six updated role TOMLs parsed. The documentation's JSON examples were parsed and its illustrative contract/task passed the actual validators.

Guarded launch of `run --phase MVP` in the real workspace correctly stopped at the pending-scope approval gate before invoking Codex. No Git repository, development branch, app scaffold, Firebase resources, SQLite database, schedule, or service was created. The ignored `.autonomy/` folder contains only local runner operational artifacts from the guarded check.

An independent gpt-6-sol/high reviewer inspected the runner. Findings led to fresh final phase-wide QA, supervisor-owned completion receipts, state-before-board checkpoint writes, EOF-safe event draining, separate verification budget expiry, Windows parent-death containment, collision-free linked defects, malformed-report gates, protected stdin cleanup, and idempotent completed-phase startup. Regression checks cover the fixes.

Live authenticated `codex exec` development, named-role spawning, QA model execution, actual application checks, and cloud/platform tests were not performed. Windows Codex 0.162 is the live supervisor's supported target; effective native team settings are checked before any model call. Strict aggregate token or monetary budget requests stop safely because full specialist/billing accounting is unavailable; parent-reported usage is diagnostic only. Runs are manually started and bounded, with no automatic reboot schedule. Runtime exhaustion is preserved unfinished work, not phase completion.
