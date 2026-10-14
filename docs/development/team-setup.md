# Native Codex team: setup and invocation

## Installation snapshot

Inspected 2026-10-12 (Australia/Brisbane): desktop bundled Codex `0.162.0-alpha.17.2`; PATH Codex CLI `0.137.0`; installed Flutter `3.44.4` and Dart `3.12.2`. This workspace initially held a PRD and HTML design, with no app, project configuration, Git checkout, or graph index.

The desktop model catalog fetched on 2026-10-12 lists gpt-6-astra, gpt-6-sol, and gpt-5.6-terra with the requested high/medium reasoning levels. Catalog support is not a live execution test. No models were substituted.

| Role | Model | Effort |
| --- | --- | --- |
| Primary Tech Lead / tech_lead | gpt-6-sol | medium |
| architect | gpt-6-sol | medium |
| backend_developer | gpt-6-sol | medium |
| flutter_flame_developer | gpt-6-sol | medium |
| qa_engineer | gpt-5.6-terra | medium |
| code_reviewer | gpt-6-sol | medium |

## Configuration

`.codex/config.toml` sets primary model/effort and explicitly registers six role files. Native multi-agent tools are enabled by default in the supported runtime. `AGENTS.md` limits active specialists to three (primary excluded); this limit is an instruction, not a runtime setting in this configuration. Each standalone `.codex/agents/*.toml` contains name, description, developer_instructions, model, and model_reasoning_effort. Reviewer additionally uses a read-only sandbox. Other roles inherit the session's permission policy; this setup does not weaken permissions or change global configuration.

The Lead is the primary coordinator; do not spawn a duplicate Lead. Its standalone definition supports explicit bounded coordination tasks. The optional local Python supervisor provides bounded, manually started Codex execution and evidence validation. It uses native Codex sessions and specialists; it creates no background schedule and does not replace them with simulated agents.

Official references: [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents) and [Configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference). The current format supports independent per-role settings and project-scoped agent definitions. Installed-version validation is recorded separately in [validation](validation.md).

## Use in the desktop

Start a new chat in this project after creating the configuration so project instructions/configuration are loaded. Select gpt-6-sol with Medium in the composer if the desktop preserves a previous model selection; confirm it rather than assuming a project default changes an existing chat. Ask the primary agent to act as Tech Lead and use the named native roles. Existing sessions may not reload new custom roles/settings immediately.

Project-local configuration is gated by project trust. No matching trust entry was found in the inspected user config. If the new session reports that local configuration is disabled, use the client's project trust flow before relying on these role definitions. For CLI use, the native diagnostic specifies a trusted project entry in user-level config; this setup does not edit that machine-level security setting. The isolated validation used a temporary Codex home with only a trust entry for this workspace and confirmed that the installed runtime loads the project layer. It did not alter your actual trust settings.

Example feature request after the app exists:

> Act as Tech Lead using this project's AGENTS.md and native roles. Plan a bounded Numeracy quiz feature with acceptance criteria. Use architect only for new contracts or significant decisions, flutter_flame_developer for approved client changes, qa_engineer for meaningful tests, and code_reviewer for independent review. Use no more than three concurrent specialists, assign disjoint files, wait for their results, and summarize actual verification. Seek approval before implementing undecided architecture.

Example architecture request:

> Delegate to architect a proposed ADR for Firebase products and SQLite synchronization on Android, iOS, and Web. Use gpt-6-sol/medium. Compare practical options and define conflicts, retries, deletion, authorization, migrations, and verification. Do not implement, provision, or deploy. Return the proposed decision for my approval.

Example safe team smoke check:

> Use native architect (gpt-6-sol/medium) to inspect ADR 0001 and native code_reviewer (gpt-6-sol/medium) to independently inspect the team configuration. Each task is read-only, uses only relevant setup files, makes no edits, and returns concise findings. Wait for both and report actual models plus limitations.

## Phase commands

Use `Develop phase MVP` or `Develop phase <name>` after approving the concrete scope at `docs/product/<slug>.md`. The Lead follows [autonomous execution](autonomous-execution.md), reads the phase board, validates approval fingerprints and branch/check prerequisites, and starts the same supervisor entry point used by the CLI. Its resumable native Lead session continues across ready tasks and fixes until completion or a recorded run limit/blocker; the invoking chat monitors without becoming a second board writer. At most three specialists run concurrently.

The [MVP scope](../product/mvp.md) is **Proposed**. Its limited Firebase sync is an explicit proposed addition to the historical Phase 1. Creating this orchestration does not approve that scope or app implementation. Future phases use [the phase template](../product/phase-template.md) and receive their own scope/contract approval.

MVP is already registered with pending approval: start with `python scripts/autonomy/supervisor.py status --phase MVP`. Use `init --phase <new-phase> --scope docs/product/<new-phase>.md` only for a future unregistered phase, and `run --phase MVP --codex <executable>` after its prerequisites are approved. Approval is separately recorded by the operator with `approve --phase MVP --contract <contract.json> --branch <branch> --approved-by <approval-reference>` after actual user approval; an agent cannot approve itself. See the execution guide for full commands, shared board and lock, evidence gates, and check contracts. Defaults are six launches, 3,600 seconds total and 600 seconds per slice. Limits are cumulative across restarts. Operator-only `--renew-budget` resets runtime/launch usage, while `--retry-after-diagnosis` clears CLI failure/no-progress counters after a new diagnosis; neither resets task retries. `--max-tokens` and `--max-cost` currently fail closed because aggregate token/billing accounting is unavailable; there is no claimed strict monetary cap.

## CLI and limitations

Live supervisor execution is currently restricted to Windows with Codex 0.162. Suspended-child Windows Job containment terminates descendants when the parent exits; persisted verification receipts precede board checkpoints, and restart may repeat verification. No startup service is installed: resume manually from disk after reboot. Report role fields are not cryptographic proof of separate agent identities; the Lead must ensure actual independent QA/review.

The older PATH CLI did not load the proposed modern settings during the initial strict configuration probe. This setup targets the inspected desktop runtime. Do not silently switch to legacy syntax, upgrade tools, or replace models. If using a CLI, check its version/schema first and update it separately if necessary. The inspected desktop bundled executable is at `C:\Users\dothn\AppData\Local\OpenAI\Codex\bin\2e5e00daee91c61d\codex.exe`; this versioned path can change after updates.

The active chat's native spawn tool supports fresh-context model/effort overrides, but does not expose a custom-role selector and does not list gpt-5.6-terra as an override. The completed read-only demonstration used architect/reviewer settings with explicit role instructions. The native configuration reader separately verified all six role registrations and paths; an automatic custom-role spawn and QA model execution were not tested. QA remains configured as requested and must be validated in a newly loaded client exposing that role/model; do not silently replace it.

Standalone CLI diagnostics from the sandbox reported unavailable auth/connectivity. This does not establish that the signed-in desktop is unauthenticated; no credential files were read or changed. No platform/application tests apply before an app exists. Worktree isolation requires a Git repository, which this setup does not create.

## Model configuration update - 14 October 2026

The user approved retaining the current configuration: primary Lead, tech_lead, architect, backend_developer, flutter_flame_developer and code_reviewer use gpt-6-sol/medium; qa_engineer remains gpt-5.6-terra/medium. The supervisor verifies these exact assignments and the project-local role paths. Earlier validation records describe the settings tested at that time, not this updated configuration.
