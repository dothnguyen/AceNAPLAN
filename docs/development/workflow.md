# Team workflow and handoffs

The primary Codex agent is Tech Lead. Six native role definitions live under `.codex/agents/`, but do not launch six agents for every request. Use at most three concurrent subagents and release completed work before starting more when the runtime requires it. Specialists do not delegate.

## Choose roles by scope

| Task | Typical participants |
| --- | --- |
| Trivial documentation or small local change | Lead directly; check the affected result |
| Routine screen/widget | Flutter developer; QA/reviewer as risk warrants |
| New feature or module | Architect when boundaries change; implementer; QA; reviewer |
| SQLite/Firebase sync or persistence | Architect first, then backend/client with separate ownership, QA, reviewer |
| Review only | Reviewer; explorer/architect only when necessary |

## Approved phase execution

For `Develop phase MVP` or `Develop phase <name>`, use [autonomous execution](autonomous-execution.md). Read `docs/product/<slug>.md` and the selected entry in `task-board.json`; verify externally given approval, scope/contract hashes, authorized development branch, requirements and mandatory checks. MVP is currently a proposal. Neither orchestration setup nor the historical PRD grants phase implementation approval.

The invoking chat launches and monitors the same bounded supervisor used by CLI runs. Its resumable Lead session owns the shared board/progress record under the supervisor execution lock; specialists never write them. Repeat the sequence below across ready tasks until the approved phase is complete, continuing independent work around blockers. Task states are `backlog`, `ready`, `in_progress`, `testing`, `review`, `blocked`, and `done`. Submit integrated clean-source candidates in `review`; the supervisor validates evidence, reruns approved checks and marks `done`.

## Sequence

Lead plans acceptance criteria and dependencies. Architect reviews significant choices and records proposed ADRs; user approval precedes dependent implementation. Implementers work in assigned files. Run inexpensive formatting/static checks and targeted tests, then QA verification, then independent review. Lead coordinates fixes, reruns affected checks, and integrates when criteria are met. Bind acceptance, QA and independent review evidence to Git HEAD plus source digest. Create linked defect tasks from findings, fix blockers, rerun affected checks and review changed revisions. Select the next ready task after completion; do not end the phase at the first finished feature. After three failed attempts, diagnose and try a materially different safe approach, then record unresolved blockers and continue independent work. Completion requires every approved requirement, all mandatory final phase checks, final independent review, and no blocking defect. Budget expiry or an unavailable platform requires a checkpoint, never a false pass. Do not deploy or merge protected branches without explicit approval; scope, significant architecture and privacy changes also need the applicable approval.

## Delegation packet

Provide objective, phase/task/requirement IDs, acceptance criteria, exact relevant paths/ADRs, ownership (editable/read-only paths), dependencies and approved choices, model/effort, required checks, and expected deliverables. Avoid sending the whole repository/history. Resolve shared manifest/migration changes serially through the Lead. Use native worktrees for necessary isolation once a Git repository exists; this setup does not initialize Git.

## Report format

Return: outcome; changed files or findings; actual commands and results; remaining risk/blocker; next decision if needed. QA defects include reproduction plus expected/actual behavior. Reviewer findings include priority, file/line, concrete failure, and impact. Acceptance, QA and review reports identify task IDs, the inspected snapshot, role and findings, including an explicit empty finding list when applicable. The Lead records their paths and referenced approved check IDs in the board. Lead's final report covers phase/requirement coverage, changes, tests, resolved/open review findings, risks, remaining tasks, run limits and approvals. Keep reports concise and never copy long logs unless needed to diagnose a failure.

## Token policy

Use only relevant roles and targeted file reads. Reuse ADRs. Do not ask two agents to repeat the same investigation unless independent verification has clear value. Run deterministic checks before expensive review. Use requested role defaults, lowering effort only where appropriate and supported; disclose any model substitution before using it. Parent and specialist settings are independent. Higher effort is justified by ambiguity or consequence, not every routine edit.

## Validation boundaries

The initial setup validation checks TOML/config loading and a small read-only native delegation. It is not a test of Firebase, SQLite, Flutter, Flame, or any target platform. A configured definition does not establish that its model ran; record dispatched models separately from catalog-supported models.
