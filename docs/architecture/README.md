# Architecture status

The workspace is a planning/design scaffold, not an implemented Flutter application. Existing artifacts are `plan/naplan_quest_year_5_prd.md` and `design/AceNAPLAN.html`. There is no `pubspec.yaml`, backend, tests, or Git repository. This setup adds development instructions and native Codex roles only.

## Approved direction

- Flutter/Dart for Android, iOS, and Web.
- Flame for educational mini-games.
- Firebase backend, SQLite local app data, and synchronization between them: [ADR 0001](adr/0001-firebase-sqlite-direction.md).

The user's attached setup brief and subsequent approvals supersede the PRD's Godot alternative and specific Firebase/LLM pipeline suggestions. Preserve the PRD as historical product input; do not treat it as an approved infrastructure design or verified educational specification.

## Decisions still open

The Architect must propose Firebase products and regions, authentication/learner identity, SQLite library and Web storage strategy, state management, routing, dependency injection, schemas, and synchronization semantics. Account-free/offline use, parent/student relationships, data retention/deletion, and writing evaluation also require product/architecture decisions. No AI writing service is approved by this setup.

Evaluate Web SQLite initialization, persistence support, browser constraints, migrations, and failure recovery alongside mobile support. Define ownership and conflict policy per entity rather than using a universal last-write-wins assumption. Design durable pending writes, acknowledgements, idempotent retries, content versions, deletions/tombstones, and account switching before implementing sync.

## Proposed boundaries (not approved implementation)

Use feature-oriented modules where useful, with presentation depending on application/domain contracts and infrastructure implementing those contracts. Domain scoring and learning/game rules should not depend on Flutter rendering, Flame, SQLite, or Firebase. Local persistence and remote synchronization are infrastructure concerns; Flutter screens and Flame adapters consume testable application services. Add only abstractions justified by testing or multiple implementations.

Before implementing persistence/sync, an approved ADR must define entity models, source-of-truth policy, queue/transaction semantics, conflict/deletion handling, authorization, migration/versioning, and Android/iOS/Web acceptance checks. Firebase local caching is not a substitute for the user-approved SQLite store.

## Decision process

Architect authors proposed ADRs using [the template](adr/0000-template.md). Lead presents significant unresolved choices for user approval and records approval evidence. Recommendations are not approvals. Do not create cloud resources, add external services, or deploy as part of an architecture recommendation.
