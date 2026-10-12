# Autonomous execution of an approved phase

`Develop phase MVP` and `Develop phase <name>` request sustained execution of the selected, approved phase. The Lead reads `docs/product/<slug>.md`, approved ADRs, `docs/development/task-board.json`, and `docs/development/progress.md` before work. A phase name resolves to its board slug; never silently fall back to MVP or infer another phase's approval. The MVP document currently has **Proposed** status. Orchestration implementation is authorized; app and MVP scope implementation are not yet authorized.

## Scope and approval gates

Every phase needs a scope document with requirements and feature IDs, acceptance criteria, exclusions, dependencies, required checks, and unresolved decisions. Start a later phase from [the phase template](../product/phase-template.md). A human approves the concrete scope, development branch, and check contract before dependent phase work starts. Recommendations and an agent's own completion message are not approval evidence.

The board's approval records `scope_sha256`, `contract_sha256`, and `development_branch`. The contract contains unique requirement IDs, approved check IDs mapped to argument arrays, and the mandatory phase check IDs. Both the approved scope bytes and the requirements/check contract must match at launch and resume. Changes invalidate the earlier approval; seek approval for the revised scope or contract. The current `approve` command refuses to overwrite an existing approval: use a newly registered phase for a revised scope unless an explicit approval-revision workflow is separately implemented; do not edit approval hashes by hand. A feature cannot silently add a service, library, data collection, or product requirement outside approved decisions.

Git initialization and branch creation need separate authorization under AGENTS.md. Scope approval does not initialize a repository, select a branch on the user's behalf, or permit changes on a protected branch. Scope inspection, proposal, and orchestration setup can proceed before a Git repository exists; phase implementation must satisfy the runtime's branch and revision gates first.

## One persistent board and coordinator

`docs/development/task-board.json` stores phases keyed by slug. `docs/development/progress.md` is the shared concise handoff record; runtime logs and temporary output belong under ignored `.autonomy/`. The Lead alone owns board/progress updates. Specialists return evidence and proposed task changes to the Lead; they do not write these shared files.

The desktop/native command and any user-requested native goal use this same supervisor after preflight, then monitor it. The Codex execution session inside the bounded run performs the Lead loop; the invoking chat must not act as a second board writer. The supervisor holds an operating-system file lock on `.autonomy/runner.lock` for the whole run (`msvcrt` on Windows, `flock` elsewhere). Never bypass the lock or delete it using stale-PID assumptions. A user-requested native goal also obeys the native goal lifecycle; this document does not authorize creating goals automatically.

Task states are `backlog`, `ready`, `in_progress`, `testing`, `review`, `blocked`, and `done`. Each task has a stable ID, requirement/feature linkage, dependencies, bounded objective, acceptance criteria, owner and file ownership, required checks, attempts, and evidence. Keep unmet work visible. A failed check, unresolved finding, unavailable platform, or outstanding approval cannot become success through a status change.

## Lead execution loop

1. Validate the selected phase's scope/contract approval, revision/branch, shared state, applicable ADRs, runtime capabilities, and run limits. Resume from persisted state and reconcile interrupted tasks before assigning more work.
2. Select ready work whose dependencies are satisfied. Prefer blocking defects, then tasks carrying acceptance risk or unlocking dependent work; use stable task IDs to break ties. Continue independent authorized work while another item awaits approval or an external dependency.
3. Give each specialist the objective, acceptance criteria, requirement/feature and task IDs, approved choices/ADRs, permitted files, dependencies, model/effort, required checks, and concise output format. Use at most three concurrent specialists with disjoint ownership; the Lead serializes shared manifest, migration, and dependency edits. Specialists do not delegate. Confirm role availability and never substitute an unavailable model silently.
4. Implement approved work, then run inexpensive formatting/static checks and targeted tests. QA verifies relevant behavior and reports exact commands, environment, outcomes, and reproducible defects. Do not run Flutter tests before a Flutter project exists or report a platform as tested without executing it.
5. Obtain independent review of the candidate revision. Persist acceptance, QA, and review report paths; reference approved check IDs. Record the `snapshot` containing Git HEAD and source digest. Task reports bind to `snapshot` and `task_id`, identify `role` and `kind`, and carry `status: "passed"` only for actual success. Review reports explicitly list `findings`. Exact formats are below. Test logs and structured reports must describe what actually ran; an implementer's claim alone is insufficient.
6. Turn actionable QA/reviewer findings into linked defect tasks with reproduction, expected/actual behavior, severity, owner, and closure checks. Resolve blockers, rerun affected checks, and obtain review covering the changed revision. A changed source digest invalidates earlier completion evidence; report/log-only changes do not justify pretending the source was reviewed again.
7. The Lead submits a candidate task in `review` after integrating it on the approved branch with clean source and complete evidence. Only the supervisor marks it `done` after independently executing referenced approved check commands and validating acceptance, QA, and independent review for that snapshot. It retains the check logs. Operational board/progress files and `.autonomy/` are excluded from the source snapshot; dirty tracked source cannot satisfy completion. Evidence references include `acceptance_report`, `qa_report`, and `review_report`; approved check IDs belong in the task's `test_requirements`, and actual check results are written by the supervisor to `verification.checks`; a report path alone is not a passing check.
8. Persist the board and a short progress entry, release completed specialists, and select the next ready task. After three failed attempts on the same task, obtain a different specialist's diagnosis and record a materially different safe approach before retrying. The diagnosis report format is below; task retry counts never decrease. Do not loop indefinitely on the same command. If no authorized approach remains, record the blocker and continue independent tasks.
9. Close the phase only after every approved requirement is covered by completed work, all mandatory phase checks pass on the final snapshot, fresh phase QA covers every requirement and every task criterion at that snapshot, final independent review covers all task IDs, release-candidate documentation exists, and no blocking defect or unresolved acceptance item remains. Otherwise checkpoint at a run limit or stop when only blocked work remains; report the exact remaining work and required decision. A budget expiry, unavailable test environment, or empty ready queue is not completion.

## Optional manually started supervisor

The Python entry point is a bounded local wrapper whose live execution currently requires Windows and the inspected Codex 0.162 runtime. Other platforms/versions fail preflight pending compatibility validation. It does not provide a scheduled service or change sandbox, trust, authentication, model availability, or permission policy. Specify the executable explicitly because the historical PATH CLI and desktop runtime differ. Check the current executable/version; do not assume the versioned desktop path in [team setup](team-setup.md) still exists.

MVP is already registered with pending approval. Inspect it first; running `init` again fails without overwriting its state:

```powershell
python scripts/autonomy/supervisor.py status --phase MVP
```

Register a future phase only once, after preparing its proposed scope (replace `reading` with its chosen slug):

```powershell
python scripts/autonomy/supervisor.py init --phase reading --scope docs/product/reading.md
python scripts/autonomy/supervisor.py status --phase reading
```

Prepare a contract JSON containing `requirements`, `checks`, and `required_phase_checks`. `requirements` is an array of unique IDs from the scope, `checks` maps unique IDs to executable argument arrays, and `required_phase_checks` lists mandatory IDs from that map. Approve real project checks, not a dummy success command. The contract is reviewable input and does not itself establish user approval.

Only the operator records actual, externally given user approval with this command; agents must not run it on their own:

```powershell
python scripts/autonomy/supervisor.py approve --phase MVP --contract <contract.json> --branch <approved-development-branch> --approved-by <user-approval-reference>
```

The placeholders must be replaced with the reviewed contract, authorized development branch, and evidence identifying the user's approval. This command records approval; it does not solicit or manufacture it, and does not authorize Git initialization, branch creation, or deployment.

The Lead maintains task records through the board helper and can inspect ready work:

```powershell
python scripts/autonomy/board.py task --phase MVP --input <task.json>
python scripts/autonomy/board.py ready --phase MVP
```

After approval and prerequisites are satisfied, start the bounded run manually:

```powershell
python scripts/autonomy/supervisor.py run --phase MVP --codex <path-to-compatible-codex.exe>
```

Replace `MVP` and the scope path with the selected phase for every command. The supervisor launches Codex using a named resumable session and structured results. It preserves phase identity and state between slices; it does not start an unrelated chat each time. Defaults are six launches, 3,600 seconds total, and 600 seconds per slice. These are upper bounds, not a guarantee of task completion or six retries for every failure. Runtime limits and checkpoint results must remain honest even when the phase is unfinished.

Runtime flags are `--max-launches` (default 6), `--runtime-seconds` (default 3600), and `--slice-seconds` (default 600). Launch/time usage is cumulative across manual restarts. Only an operator may use `--renew-budget` to reset that cumulative budget; it does not reset task retry counts. Only an operator may use `--retry-after-diagnosis` after documenting a new diagnosis to clear CLI-launch failure and no-progress counters. Neither flag grants scope approval or waives task evidence. Interrupted/failed launches stop the run for inspection; after three failed launches an explicit diagnosed retry is required, and two unchanged checkpoints stop for diagnosis.

`--automatic-review` forwards the installed runtime's `--approve-for-me` flag to new and resumed execution. Workspace-write sandboxing remains active; individual requests for required SDK/cache, network or Git operations are reviewed by the native approval reviewer. This does not grant blanket filesystem access, change the phase contract or guarantee approval. Default runs retain their existing routing. The operator enabled this path for the approved pilot after a sandbox-only run could neither update Flutter/Dart tool state nor commit authorized local changes.

`--max-tokens` and `--max-cost` are optional operator inputs but currently fail closed before model execution because full aggregate coordinator/specialist token and billing accounting is unavailable. Parent-reported tokens are diagnostic only. No strict token or monetary cap is claimed for an ordinary run. Read `--help` for the installed wrapper's supported arguments.

Windows starts each supervised child suspended, places it in a kill-on-close Job, then resumes it. Parent exit closes the Job and terminates descendants, preventing an orphaned child from continuing to write after the supervisor dies. Runtime receipts are atomically persisted before board checkpoints, so a crash can leave an older review candidate to verify again rather than a falsely completed task without a receipt. An interrupted reserved slice is charged on resume; verification may repeat. These safeguards do not guarantee that every interruption saves the model's latest work.

No background schedule or startup service across reboot is installed. Restart manually from the persisted board and `.autonomy/state/<slug>.json` when needed; do not delete runtime state to reset budgets or verification history. On completion or stop, inspect status and the progress record, including failing check logs, current snapshot, remaining tasks, and approval blockers. A process exit alone is not evidence that the phase is complete.

## Contract, task and report examples

These examples show the implemented JSON shapes for a fictional `example` phase after a Flutter app exists. They are not the MVP contract, runnable checks in this planning workspace, evidence of passing work, or approval. A real MVP contract must include all MVP requirements and mandatory checks. Replace example IDs, paths, criteria, commands, snapshot strings, and evidence with the approved phase's actual values. Check commands are argument arrays, not shell command strings; on Windows approve a concrete executable or explicit shell invocation suitable for the tool being run.

Example contract:

```json
{
  "requirements": ["EXAMPLE-01"],
  "checks": {
    "EXAMPLE-SCORING": ["C:/flutter/bin/cache/dart-sdk/bin/dart.exe", "test", "test/scoring_test.dart"]
  },
  "required_phase_checks": ["EXAMPLE-SCORING"]
}
```

Example task input for `board.py task --phase example --input <task.json>`:

```json
{
  "id": "EXAMPLE-T01",
  "description": "Verify deterministic scoring under the approved rule",
  "epic": "EXAMPLE-CORE",
  "feature": "EXAMPLE-F01",
  "assigned_agent": "flutter_flame_developer",
  "status": "backlog",
  "priority": 1,
  "retry_count": 0,
  "dependencies": [],
  "acceptance_criteria": ["Correct answers earn the approved score"],
  "relevant_files": ["lib/domain/scoring.dart", "test/scoring_test.dart"],
  "test_requirements": ["EXAMPLE-SCORING"],
  "requirements": ["EXAMPLE-01"],
  "subtasks": [],
  "blocker": null
}
```

New tasks start in `backlog`. Update the full record through legal transitions: `backlog → ready → in_progress → testing → review`; the supervisor alone moves `review → done`. Blocked tasks resume through `backlog` or `ready`; completed work is reopened through a linked defect task. Ready ordering is numeric `priority` (0 highest through 3) then ID, subject to completed dependencies; the Lead assigns priority to express blocking defects and acceptance risk. `relevant_files` does not replace explicit editable/read-only ownership in the delegation packet.

After authorized integration, get the actual source fingerprint:

```powershell
python scripts/autonomy/board.py snapshot
```

The result is `{"head": "<actual Git HEAD>", "source_sha256": "<actual source digest>"}`. Put reports under `.autonomy/evidence/<phase>/` to avoid changing the source fingerprint when recording evidence. Add this object to the candidate task as `evidence`, retaining its other fields and transitioning it to `review` only after the required earlier states:

```json
{
  "snapshot": {"head": "ACTUAL_HEAD", "source_sha256": "ACTUAL_SOURCE_SHA256"},
  "acceptance_report": ".autonomy/evidence/example/EXAMPLE-T01-acceptance.json",
  "qa_report": ".autonomy/evidence/example/EXAMPLE-T01-qa.json",
  "review_report": ".autonomy/evidence/example/EXAMPLE-T01-review.json"
}
```

The acceptance report is authored by QA and covers the exact task criterion strings, each with actual evidence:

```json
{
  "kind": "acceptance",
  "task_id": "EXAMPLE-T01",
  "role": "qa_engineer",
  "status": "passed",
  "snapshot": {"head": "ACTUAL_HEAD", "source_sha256": "ACTUAL_SOURCE_SHA256"},
  "criteria": [
    {"criterion": "Correct answers earn the approved score", "passed": true, "evidence": "Actual test command, environment and passing log reference"}
  ]
}
```

The separate QA report uses `kind: "qa"` with the same task, QA role, status and snapshot, and should retain actual verification details:

```json
{
  "kind": "qa",
  "task_id": "EXAMPLE-T01",
  "role": "qa_engineer",
  "status": "passed",
  "snapshot": {"head": "ACTUAL_HEAD", "source_sha256": "ACTUAL_SOURCE_SHA256"},
  "commands": ["Actual command and environment"],
  "results": ["Actual outcome and log reference"],
  "limitations": []
}
```

Independent task review uses this shape:

```json
{
  "kind": "review",
  "task_id": "EXAMPLE-T01",
  "role": "code_reviewer",
  "status": "passed",
  "snapshot": {"head": "ACTUAL_HEAD", "source_sha256": "ACTUAL_SOURCE_SHA256"},
  "findings": []
}
```

Each finding includes `priority` (`P0`, `P1`, `P2` or `P3`) and `resolved`, plus concrete file/line, failure scenario, impact and resolution evidence. Unresolved P0/P1 findings fail the mechanical gate. Lower-priority findings must still be resolved if they block acceptance; retain any accepted nonblocking limitation in the release documentation. Role strings and report files are not cryptographic proof of distinct agents or honest reviews. The Lead is responsible for obtaining actual independent QA/review, while the supervisor reruns approved commands and checks report bindings.

When a task requires a different diagnosis after repeated failure, its `diagnosis_report` references JSON such as:

```json
{
  "kind": "diagnosis",
  "task_id": "EXAMPLE-T01_FIX",
  "role": "architect",
  "retry_count": 3,
  "new_approach": "Actual diagnosis of prior failures and a materially different authorized approach"
}
```

Use the blocked task's exact current retry count and a native specialist role different from its `assigned_agent`. This task diagnosis is separate from the operator's diagnosed retry of CLI launch failures.

After all tasks are supervisor-verified, obtain fresh phase QA for the final snapshot. The actual `requirements` list must cover every approved requirement, and `task_acceptance` must cover every task, including defect tasks and each exact criterion:

```json
{
  "kind": "phase_qa",
  "phase": "example",
  "role": "qa_engineer",
  "status": "passed",
  "snapshot": {"head": "ACTUAL_HEAD", "source_sha256": "ACTUAL_SOURCE_SHA256"},
  "requirements": [
    {"id": "EXAMPLE-01", "passed": true, "evidence": "Actual final requirement verification evidence"}
  ],
  "task_acceptance": [
    {"task_id": "EXAMPLE-T01", "criteria": [
      {"criterion": "Correct answers earn the approved score", "passed": true, "evidence": "Actual acceptance evidence at the final snapshot"}
    ]}
  ]
}
```

Final independent review covers every task ID, including defect tasks, at that same snapshot:

```json
{
  "kind": "phase_review",
  "phase": "example",
  "role": "code_reviewer",
  "status": "passed",
  "snapshot": {"head": "ACTUAL_HEAD", "source_sha256": "ACTUAL_SOURCE_SHA256"},
  "task_ids": ["EXAMPLE-T01"],
  "findings": []
}
```

The Lead records phase-level `evidence` containing `qa_report`, `review_report`, and `release_candidate` paths. `release_candidate` points to a nonempty release document with completed requirements, checks/environments, known limitations and user acceptance steps; it does not authorize deployment. The supervisor reruns the union of mandatory phase checks and all task checks before accepting completion. A task's earlier success does not replace fresh final phase QA.

At each slice the Lead's final structured response has `phase` (the slug), `outcome` (`continue`, `needs_approval`, `blocked`, or `complete`) and a concise `summary`. Return `continue` when tasks await supervisor verification. `complete` requests final verification; it is not itself a completion receipt. Preserve board/progress state before yielding.

The supervisor stores a separate phase completion receipt in its runtime state before writing the completed board. Repeating a run for an unchanged completed phase verifies that receipt, the source snapshot, task receipts, and report hashes, then returns without launching a model. Changed source/evidence requires a revalidation decision; the board's `complete` label alone is never sufficient.

## Approval and capability boundaries

Escalate changes to approved scope, significant architecture/dependencies/services, unresolved learner identity and child-data/privacy decisions, destructive operations, deployment, production database changes, and protected-branch merges. Keep independent approved work moving. The Firebase/SQLite direction does not approve Firebase products, authentication, synchronization policy, cloud provisioning, or an AI writing service.

Configured role definitions are not runtime proof. The existing diagnostics did not establish automatic custom-role loading or execution of `gpt-5.6-terra` for QA. If the current runtime cannot launch a required role/model, record that capability blocker; do not silently substitute it or claim QA completed. App tests and Android/iOS/Web execution remain unverified until actually run.
