# ADR 0001: Firebase backend with SQLite local data and synchronization

Status: Accepted direction; implementation design pending
Date: 2026-10-12 (Australia/Brisbane)
Owner: Architect

## Context and decision

The user specified: "firebase for backend, but app data will be stored in a sqlite database, and sync with backend" and approved the team setup incorporating that direction.

Use Firebase as the backend and SQLite as the local application data store, with synchronization between them. Flutter and Flame target Android, iOS, and Web. Support useful offline learning behavior under a subsequently approved product/sync contract.

## Scope of approval

This accepts the technology direction only. Firebase products (including Firestore versus Realtime Database), regions, authentication, SQLite package/Web implementation, sync protocols, conflict policy, and deployment remain unspecified. No Firebase project or external service is provisioned. State management, routing, and dependency injection are also undecided.

## Required follow-up design

Define entity identity/ownership, question/content versions, local transactions, durable operation queue, remote acknowledgement, retry/idempotency, conflict resolution per entity, deletions, schema migrations, account switching, and server-side authorization. Evaluate browser persistence and initialization constraints instead of assuming mobile SQLite works on Web. Separate educational/domain logic from both storage systems.

## Consequences

Local persistence supports offline interactions but adds synchronization and migration complexity. Client and backend developers must share an approved contract with explicit file ownership. QA must verify reconnect/retry, concurrent changes, interrupted writes, learner isolation, deletion, and migrations on applicable platforms. Practice data should minimize identifying information and avoid sensitive logs.

## Approval evidence

Approved by the user in this setup conversation on 2026-10-12 after specifying Firebase/SQLite synchronization. Detailed architecture and cloud operations require their own approval.
