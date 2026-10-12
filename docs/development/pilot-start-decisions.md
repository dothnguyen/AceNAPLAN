# Pilot execution prerequisite packet

Date: 13 October 2026 (Australia/Brisbane)
Status: Approved by the user on 13 October 2026: “approve phase scope, lets develop pilot phase”, in response to this prerequisite packet. Git initialization/branch, ADR 0002, narrow project trust and the exact verification contract are authorized. Publication remains separate.

The user's command “Develop pilot phase” authorizes advancing the current Android pilot. The phase has been registered in the persistent board. This packet resolves prerequisites explicitly left open in AGENTS.md and the pilot scope; it does not ask the user to repeat the phase request.

## Concrete decisions to approve

1. Initialize this workspace as a Git repository on `development/pilot`, commit the existing planning/orchestration baseline, and permit scoped local implementation commits on that branch. No remote, push, protected merge, history reset or deployment is proposed.
2. Accept proposed ADR 0002: Flutter Android phone/tablet app; shared domain/application code; Android SQLite through sqflite/path; explicitly marked in-memory Web QA repository; built-in ChangeNotifier, constructor injection and Navigator; bundled audio through audioplayers; local-only anonymous learner, no accounts/analytics/cloud provisioning/sync in this pilot. See the exact boundaries and alternatives in the ADR. Keep Firebase synchronization as the later approved architecture direction.
3. Trust only `c:\works\projects\acenaplan5` in the user's Codex config so project-local native role settings load. Add/preserve the project trust entry without changing authentication, permissions, other projects, providers or models. The current user config has no matching entry; untrusted loading cannot be assumed to activate the team.
4. Accept the proposed requirement/check contract in `pilot-check-contract.proposed.json`. Its named app tests and verification helper are phase implementation deliverables, not currently runnable or already passed. Helpers must independently execute applicable checks or validate genuine revision-bound evidence, fail on missing/stale/invalid evidence, and never manufacture educator or physical-device results. Each opaque gate needs documented evidence/schema and meaningful regression checks before use.

## Scope interpretation

The user selected `design/AceNAPLAN.html` as the implementation design reference. Apply the phone/tablet screen mapping and pilot adaptations in `docs/product/pilot-design-reference.md` within the existing pilot boundaries.

Use the current catalogue: 16 Numeracy plus 6 Conventions families, 20 reviewed items each (440). Generation is now phase implementation work, not a planning-time draft. An educator reviews actual items, mappings, explanations, audio and stimuli before release inclusion. No placeholder bank/audio is a completed deliverable. Browser verification is supplemental; Android persistence/native checks remain mandatory. Publishing is a separate approval.

## Available tooling and remaining evidence

Installed desktop Codex is 0.162.0-alpha.17.2. Flutter/Dart and Android adb/emulator commands are present; SDK platforms 34 and 35 are installed. One Android target is connected through adb at `127.0.0.1:21503`, identifies as ASUS_Z01QD, reports API 28 and hardware qcom. These properties alone do not prove physical-phone or tablet coverage; no application/device check has yet run. Installed plugin/SDK compatibility will be validated before finalizing build configuration.

No Git repository or approved development branch exists. There is no app scaffold, content bank or audio. The prematurely generated draft from earlier planning was removed. No actor may treat available tooling or proposed commands as passing checks.

## Later user participation

Educator approval and representative real phone/tablet evidence will be needed before final phase completion. A release signing identity may also require operator provisioning; secrets stay out of source control. These do not prevent independent approved implementation/testing tasks from progressing once setup is approved. When only these gates remain, report precisely what is ready and what evidence is missing; do not declare the phase complete or weaken its scope.

## Execution limits

Use the installed bounded supervisor and original six model assignments. Initial run uses its configured defaults: three specialists maximum, six launches, 3,600 seconds total, 600 seconds per slice. Preserve checkpoints and incomplete work if the budget expires. Strict aggregate token/cost ceilings are unavailable and must not be claimed. No scheduled/background restart service is proposed.
