# Phase <name>

Status: **Proposed — not approved for implementation**

Phase slug: `<slug>`  
Scope path: `docs/product/<slug>.md`

## Outcome and source

Describe the bounded learner/product outcome, source proposals, and how this phase builds on earlier completed phases. Distinguish historical proposals from approved direction. State any proposed addition explicitly.

## Requirements and features

Replace every placeholder before approval. Use stable unique requirement and feature IDs, and map tasks to them.

| Requirement ID | Feature ID | Included behavior | Acceptance evidence |
| --- | --- | --- | --- |
| `<PHASE>-01` | `<PHASE>-F01` | Concrete behavior and supported environments | Observable success, failure and edge cases with evidence |

Specify content volumes, interaction types, supported platforms, data boundaries, and accessibility expectations where relevant. Do not imply NAPLAN alignment or official proficiency equivalence without validated evidence.

## Exclusions

List deferred features, explicitly excluded integrations, provisioning, deployment, and data collection. Cross-phase dependencies do not automatically add those features to this phase.

## Dependencies and decisions before implementation

Reference approved ADRs and prerequisite phases. List unresolved architecture, library, backend product, learner identity, synchronization, privacy, and product choices. Mark dependent tasks blocked until the applicable approval is recorded; continue independent authorized tasks.

## Mandatory phase checks

| Check ID | Required evidence and environment |
| --- | --- |
| `<PHASE>-CHECK-01` | Exact behavior/quality gate and required platform |

The approval contract must map these check IDs to real executable argument arrays and include them in `required_phase_checks`. Add task-specific checks when necessary. Unsupported or skipped required environments remain unmet; changing a mandatory check requires approval of the revised contract. Evidence and independent review must cover the integrated final Git HEAD and source digest.

## Approval record and completion

The operator records externally given user approval in `docs/development/task-board.json`, including this document's SHA-256, the requirements/check contract SHA-256, development branch, and approval reference. Do not treat a document status label or a filled template as approval. Git initialization and branch creation require separate authorization. Follow [autonomous execution](../development/autonomous-execution.md) to initialize, inspect, approve, and run the selected phase.

Completion requires coverage of every approved requirement, all mandatory phase checks passing, final independent review, and no blocking defect or unmet acceptance criterion. A run limit or unavailable tool cannot waive these gates.
