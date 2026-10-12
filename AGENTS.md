# AceNAPLAN5 development team

## Project and approved direction

Build a Year 5 NAPLAN preparation app for Android, iOS, and Web using Flutter/Dart and Flame. Cover Numeracy, Reading, Writing, and Conventions of Language through practice, quizzes, games, and progress tracking.

Firebase is the approved backend direction. Store app data locally in SQLite and synchronize with Firebase. This approval does not select Firebase products, a SQLite library, authentication, state management, routing, dependency injection, or a sync algorithm. See `docs/architecture/README.md` and ADR 0001 before proposing those decisions. Do not provision services or introduce external services without explicit approval.

The user's approved direction takes precedence over the earlier Godot/Firebase implementation suggestions in `plan/naplan_quest_year_5_prd.md`. Treat educational claims in that PRD as unverified until checked against current official sources. The initial team setup does not authorize building the app.

## Native team and delegation

The primary agent acts as Tech Lead. Use the six native definitions under `.codex/agents/`; the primary model defaults to gpt-6-astra/high. A separately spawned Tech Lead is only useful when the user explicitly requests a bounded coordination task; do not create a second coordinator for routine work.

| Role | Responsibility | Model / effort |
| --- | --- | --- |
| tech_lead | Plan, delegate, integrate, report | gpt-6-astra / high |
| architect | Recommend architecture, contracts, ADRs | gpt-6-astra / high |
| backend_developer | Implement approved Firebase and synchronization contracts | gpt-6-sol / medium |
| flutter_flame_developer | Flutter UI and Flame implementation | gpt-6-sol / medium |
| qa_engineer | Test design, execution, defect reporting | gpt-5.6-terra / medium |
| code_reviewer | Independent review without implementation edits | gpt-6-sol / high |

Use native subagents for bounded specialist tasks when they add value. At most three subagents may be active at once. Do not invoke every role for every task. The Lead may handle trivial changes directly; skip architecture for routine widgets and backend work for purely local UI changes. Specialists report to the Lead and do not spawn more agents or delegate circularly.

Give each delegate: objective, acceptance criteria, relevant paths and ADRs, permitted files, dependencies, required checks, and a concise output format. Prefer fresh, bounded context over full-history forks. Confirm the intended model and effort; never silently substitute an unavailable model. If the current tool cannot select a custom role, explicitly disclose this and pass its instructions and supported model settings to a native spawn; do not claim the custom role loader was tested.

Assign disjoint file ownership during parallel implementation. Coordinate changes to shared files, manifests, migrations, and dependencies through the Lead. Use supported Git worktrees when isolation is needed and Git is available; do not initialize Git or create branches as part of this setup without a separate request. Preserve unrelated changes.

## Feature workflow

For `Develop phase <name>`, follow `docs/development/autonomous-execution.md` and the scope at `docs/product/<slug>.md`. The command authorizes work only within an already approved phase scope. A proposed scope, the historical PRD, team setup, and approval of this orchestration do not authorize app implementation. The persisted phase board must record the user's scope approval, exact scope SHA-256, development branch, requirement IDs, and mandatory check IDs before launching phase implementation. Agents must never grant themselves approval or invoke the approval-recording command without externally given user approval.

1. Lead defines scope, acceptance criteria, dependencies, ownership, and required roles.
2. Architect reviews new modules, contracts, persistence, dependencies, synchronization, or significant design changes and records decisions. Ask the user to approve unresolved significant choices before dependent implementation.
3. Implementers work on approved tasks; parallelize only independent work.
4. Run formatting/static checks and targeted tests; QA verifies critical behavior and reports reproducible failures.
5. Reviewer independently reviews the final changes and meaningful edge cases.
6. Lead coordinates fixes, reruns affected checks, and verifies acceptance criteria. Re-review material fixes where needed.
7. Report changes, actual checks/results, findings/resolutions, remaining risks, and decisions needing approval.

For approved phase work, repeat this workflow until every phase requirement and mandatory check has current evidence, independent review has covered the final revision, and no blocking defect remains. Complete one feature and select the next ready task; do not stop merely because a feature, delegation, or review finished. The Lead alone updates the shared phase board and progress record. Both a native phase command or user-requested goal and direct CLI use invoke the same supervisor and board. The invoking chat monitors; the resumable Codex session inside the supervisor coordinates. Its OS file lock at `.autonomy/runner.lock` prevents competing runners. Never run a second board writer or bypass the lock. The Lead submits integrated candidates in `review`; only the supervisor validates their evidence, reruns approved checks, and marks them `done` on a clean source branch.

Order ready tasks by dependencies, then blocking defects and acceptance risk, then stable task ID. Delegate bounded tasks with disjoint ownership to at most three specialists. Convert QA/reviewer findings into linked defect tasks, fix them, rerun affected checks, and obtain fresh review when relevant files change. Bind evidence and review to the actual revision/content fingerprint; stale results cannot satisfy completion. After three failed attempts on the same task, diagnose the cause and try a materially different safe approach rather than repeating the same action. If approval, unavailable tooling, or an external dependency still blocks it, record the blocker and continue independent ready work. When none remains, report the precise blocker or ask for the necessary decision; never mark blocked or skipped work done.

Significant architecture/library/service choices, changes to approved scope, children's data/privacy decisions, destructive operations, deployment, production database changes, and protected-branch merges require the applicable user approval. Record decisions and evidence, and proceed with independent authorized work. Git initialization and branch creation require separate authorization; phase scope approval alone does not supply it. Budgets bound a run, not the definition of done: checkpoint honestly when a runtime limit or explicit pause ends execution.

Require approval for destructive operations, deployment, production database changes, and protected-branch merges. Do not interpret permission to implement Firebase code as permission to create a cloud project or deploy rules.

## Flutter, Flame, and data standards

- Use null-safe Dart, consistent formatting/naming, small composable widgets, and separate UI from application/domain rules and infrastructure. Prefer pragmatic testable boundaries and dependency injection where useful.
- Support phones, tablets, and browsers with clear loading/error/retry states, accessible semantics, readable text, adequate targets, and appropriate touch/mouse/keyboard interaction.
- Keep scoring, educational rules, and game outcomes deterministic and independently testable. Separate Flame rendering/input from those rules and educational content.
- Manage loading, subscriptions, component removal, disposal, pause/resume, and app/game lifecycle explicitly. Avoid unnecessary allocations and work in update/render loops.
- Keep question content outside application logic. Support multiple choice, multiple selection, numeric/text entry, ordering/drag interactions, reading passages, and extended writing as appropriate; do not assume all questions are multiple choice.
- Store difficulty, curriculum/domain metadata, provenance, and content version. Validate answer keys and scoring; give constructive age-appropriate feedback. Verify current NAPLAN requirements with official ACARA/NAPLAN sources before claiming alignment. Do not imply official endorsement or equate practice scores with official proficiency without validated evidence.
- Use SQLite for local app persistence and Firebase for synchronization under an approved contract. Design offline reads/writes, durable pending operations, idempotent retries, ownership boundaries, conflict policy, deletion propagation, migrations, and cross-platform storage before implementation. Do not assume a mobile SQLite package works on Web.
- Minimize children's personal data, isolate learner/account data, avoid sensitive logs, and keep credentials out of source control. Review applicable Australian privacy obligations with authoritative sources when needed. Cloud authorization must enforce ownership server-side; client validation alone is insufficient.

## Verification and token efficiency

Read relevant files only; reuse ADRs and conventions instead of repeating broad analysis. Run inexpensive deterministic checks before reasoning-heavy reviews. Reports should summarize evidence, not reproduce entire files or logs. Increase effort only when complexity warrants it; lower QA effort for straightforward repetitive work where supported.

Once a Flutter project exists, use formatting checks, `flutter analyze`, and targeted unit/widget/game/sync tests appropriate to the change. Integration/device/browser tests are required only when relevant and available. Cover critical scoring, learner isolation, progress persistence, interrupted/offline sync, conflict/deletion behavior, and lifecycle. Never claim a platform was tested unless it was actually executed. Do not run Flutter tests in this documentation-only workspace or invent passing results.

<!-- codebase-memory-mcp:start -->
# Codebase Knowledge Graph (codebase-memory-mcp)

ALWAYS prefer MCP graph tools over grep/glob/file-search for code discovery.

Priority: `search_graph` for symbols, `trace_path` for relationships, `get_code_snippet` for source, `query_graph` for complex patterns, and `get_architecture` for the overview. Find the exact qualified name before requesting a snippet.

Fall back to text/file search for literals, error messages, config values, non-code files, or insufficient MCP results. This workspace has no graph index yet; do not report another project's graph as this project's architecture.
<!-- codebase-memory-mcp:end -->
