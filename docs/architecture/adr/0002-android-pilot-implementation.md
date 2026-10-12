# ADR 0002: Android pilot, local content and progress

Status: **Proposed — explicit user approval required before dependent implementation**
Date: 2026-10-13 (Australia/Brisbane)
Owner: Architect
Scope: [pilot requirements PILOT-01–10](../../product/pilot.md)

## Context

The pilot proposes an account-free Android app with bundled, reviewed Numeracy and Conventions practice, SQLite progress, and a Web surface for shared UI verification. [ADR 0001](0001-firebase-sqlite-direction.md) accepts Firebase/SQLite synchronization as the eventual direction; this ADR proposes deferring synchronization for this pilot. It does not select Firebase products or authorize cloud resources. The repository is currently a planning and orchestration scaffold, so this is a contract for future work, not a description of implemented behavior.

## Options and tradeoffs

| Decision | Recommendation | Alternative and tradeoff |
| --- | --- | --- |
| Structure | Feature-oriented Flutter modules with pure Dart domain rules | Large layered frameworks add indirection before the pilot needs it |
| State and injection | Flutter `ChangeNotifier` controllers, constructor injection at the composition root | Riverpod/BLoC/service locators add dependencies and conventions; revisit if coordination grows |
| Navigation | Built-in `Navigator` with a small explicit route set and Back handling | A routing package becomes useful for a later deep-linking/public Web product |
| Android persistence | `sqflite` with the `path` utility, parameterized SQL and versioned migrations | Drift adds generation and abstractions; justified later if query complexity demands it |
| Web verification | In-memory implementation of the same repository contract | Web SQLite needs separate initialization/persistence validation outside this pilot |
| Audio | `audioplayers` playing packaged, reviewed audio assets | Streaming/TTS at runtime adds connectivity, privacy and reproducibility dependencies |
| Graphics | Flutter widgets and `CustomPainter` for deterministic grids, instruments, angles and charts | Bundled SVG is acceptable only with an explicitly reviewed renderer dependency; no image-generation service is needed |

Publisher documentation checked on 2026-10-13 lists `sqflite` 2.4.4+1 with Android support and experimental Web support through a separate package. This supports keeping production Android storage distinct from the Web test adapter. Pin the successfully resolved version and lockfile after SDK compatibility checks; a package page does not establish successful integration. [sqflite documentation](https://pub.dev/packages/sqflite)

`audioplayers` 6.8.1 lists Android and Web and documents bundled `AssetSource` playback and player disposal. Recommend that release or a compatible locked version within the approved major line, after actual Android and Chrome tests. Use only the asset source implementation; dependency capability does not authorize network playback or a service. [Package](https://pub.dev/packages/audioplayers), [publisher guide](https://github.com/bluefireteam/audioplayers/blob/main/getting_started.md)

## Recommendation

### Boundaries and composition

Use `lib/app/` for composition/navigation, `lib/features/practice/` for session presentation/application, `lib/features/progress/` for summaries, `lib/domain/` for shared immutable question/session/attempt models, validators, scoring and selection, and `lib/infrastructure/` for SQLite, bundled content and audio. Folder names may be adjusted without changing the dependency rules. Widgets/controllers depend on contracts; domain code imports neither Flutter nor storage/audio plugins. Use `flutter_test` and Flutter's `integration_test` for checks; do not introduce a test framework/service merely to implement this plan. Flame is deferred because this phase contains no game.

Define one `PracticeRepository` contract with atomic operations: initialize/import approved content, create/resume session, mark presented, record help, submit answer, abandon session, query summary and reset local progress. Use an injectable clock and deterministic selection seed in domain tests. Keep SQL transactions inside the Android implementation; the Web adapter must model the same atomic/idempotent behavior in memory. Conditional platform composition must avoid invoking native storage from Chrome. Android release startup must reject the test repository. Web shows a persistent “Test mode — progress resets on refresh” label.

Controller states include initializing, ready, saving, feedback and recoverable error. Serialize mutations and disable duplicate submit while saving; repository uniqueness still provides the actual duplicate protection. Persist before reporting an answer as saved. Retry reuses the original operation key. Dispose controllers/listeners and ignore stale async responses after route changes.

### Schema, identity and migration contract

Use one anonymous local learner, scoped by a fixed local-only key. It is not an account, install-tracking identifier or cross-device identity. The SQLite database in Android app-private storage is the progress source of truth; bundled approved content is the source for new content revisions. Start database schema version at 1; separately version the content schema, bank manifest, each item revision and scoring policy. Never use the app build number as the only content version.

| Entity | Required fields and invariants |
| --- | --- |
| `content_manifest` | Bank version, schema version, manifest digest, import timestamp; one active bank after commit |
| `question_revision` | Primary key `(item_id, revision)`; stable `family_id` and `variant_id`, topic/domain, difficulty, curriculum references, provenance/license, prompt/stimulus, answer rule, hint/explanation, asset references/digests, immutable content digest and review record |
| `bank_item` | Bank version to selected `(item_id, revision)` mappings; removal deactivates future selection, never cascades into history |
| `practice_session` | Local ID, mode (`fresh`/`review`), requested size, actual size, selection policy version/seed, status, created/completed timestamps |
| `session_item` | Session, ordinal, stable item ID and pinned revision, presentation/help flags and status; unique `(session_id, ordinal)` and `(session_id, item_id)` |
| `item_exposure` | Unique `(learner_key, item_id)` with first presented timestamp/session; revision changes do not reset exposure |
| `attempt` | Immutable local ID, unique submission key, session/ordinal/attempt number, pinned item revision and scoring version, normalized response, correct flag, independent/helped/review classification, timestamp |

Bound response lengths and keep only answers needed to explain a practice result; no essays or arbitrary feedback text in learner data. Persist counts by querying attempts, or use a rebuildable projection; cached totals must never become the sole record. Foreign keys must be enabled and tested. Avoid destructive `REPLACE` for versioned parent rows. Local timestamps are display/context metadata, not conflict-resolution authority.

Migration failure leaves existing progress intact and presents retry/support information; it never silently recreates the database. Apply each schema migration transactionally and test upgrade from fixtures. A newer unsupported schema/bank version fails safely rather than downgrading/resetting. Local reset requires an explicit parent confirmation, stops active operations/audio, deletes learner sessions/attempts/exposure/reservations in one transaction, retains content and returns to an empty summary. Uninstall is not a guaranteed backup/recovery mechanism.

### Atomic, idempotent seeding and content updates

1. Read the entire bundled manifest and validate schema compatibility, 22-family/440-item target, immutable IDs, review approvals, answer rules and all asset digests before writes. Drafts never enter the release bundle.
2. Open/migrate the database, then compare the active bank version and digest. The same version and digest is a no-op; the same version with different bytes is an error requiring a new bank version.
3. In one transaction insert missing immutable revisions, validate existing revision digests, write bank membership and switch the active manifest last. Errors roll back the whole import. A killed process can restart the same import safely.
4. Preserve previous revisions referenced by attempts or active sessions. Corrected wording/keys keep the stable item/variant ID and increment revision. A genuinely new variant gets a new ID. Answer-key corrections must not silently rewrite historical correctness; record a correction notice and exclude known-invalid results from recommendations until reviewed.
5. Pause new-session creation during import. Resume a saved set with its pinned revisions and retained assets; do not regenerate it. Removed/unsafe content requires an explicit retired-item path: explain that the item is unavailable, skip without a wrong score, retain its history, and label any resulting shorter session. Do not bundle withdrawn unsafe stimuli merely to keep an old session playable.

Retain assets needed by supported prior revisions in an app update or retire their unfinished session entries safely. Missing audio never becomes an incorrect answer. Test interruptions before/within/after commit, repeated import, mixed old/new sessions, content withdrawal, low-storage/write failures and historical summary continuity.

### Session reservations, exposure and exhaustion

Permit one active or paused session for this local learner. A new-session request resumes it or explicitly abandons it first. Selection and reservation commit together. A reservation prevents selecting the same item into another set but is not evidence that the child saw it. Abandoning releases only unpresented reservations; presented items remain exposed forever until an explicit local reset.

Before revealing a question, durably record presentation/exposure, then display the stimulus. Repeating this operation is idempotent. A crash after that commit may conservatively count one unseen screen as exposed; favor avoiding a repeated item labelled new. Saving a hint/help flag precedes showing help, so process death cannot reclassify a helped attempt as independent. On resume, preserve order, revision, help state and saved answers. Re-displaying an unfinished item does not create another first exposure or attempt.

For the initial policy, mixed sessions request four Numeracy and four Conventions items; topic sessions request eight from one selected topic/area. Within each domain/topic rotate eligible families with a maximum one-item difference between family allocations when possible. Start with an explicit difficulty target of four introductory and four developing items, apportioned 2+2 within each half of mixed sessions. For a topic's two families target four items per family, each with two introductory/two developing items. Content authoring supplies ten of each difficulty per family. No adaptive mastery claim is made.

The pure selector accepts eligible item IDs, exposure, active reservations, requested policy and seed and returns an ordered set plus unmet quotas. Choose only reviewed, active, compatible items. Persist the actual set once. A quota shortfall may offer a shorter fresh session; any changed mix is explained before starting. Never silently fill a fresh quota with seen items. Compare against the preceding set and choose another valid set where possible; when the bank makes this impossible, offer review with an explicit repeat explanation instead of promising novelty.

Review uses seen eligible items, labelled “Review — questions you have seen before,” and preserves its classification in summaries. Fresh exhaustion offers fewer new questions, review, or returning later after an approved content update. No live generation or history reset fills the gap. At most 30 all-new mixed sessions exist under a 4+4 split of 320 Numeracy/120 Conventions items, before other filters or earlier practice reduce capacity.

An independent first attempt is the first submitted response for an item with no prior help and no review/retry context. Invalid input produces validation feedback without a scored attempt. A wrong scored response remains wrong; subsequent work is retry/review, never a replacement independent success. Playing/replaying the standard dictation audio is normal task access, not a hint. A revealed target word is help and invalidates independent dictation scoring.

### Scoring, accessible stimuli and audio

Use typed answer rules: single choice compares stable option IDs; numeric input parses an approved decimal/integer syntax into exact scaled integers or rationals, with units fixed visibly by the item or an explicit allowed conversion rule. Reject NaN/infinity and unsupported notation; never compare floating-point values using accidental equality. Spelling trims surrounding whitespace and compares case-insensitively for the approved Australian-English target/alternatives; internal punctuation/hyphens and accented forms are accepted only when the item rule says so. Sentence choices use a stable keyed option with exactly one validated correct answer. Explain normalization in authoring fixtures and tests.

Use data-driven painters/widgets with accessible text equivalents that communicate the same problem without supplying the answer. Include axis labels/scale units, high contrast and non-colour cues; make phone/tablet layouts and large text usable. Any equivalent verbal representation needs content review for changed difficulty. No drag, hot-spot, ordering or multiple-selection interaction is added by the family catalogue.

Bundle at least one approved context recording for each of the 20 dictation words: target word, sentence, target word, with Australian-English pronunciation reviewed by a person. Store recording provenance/rights, transcript, checksum and item mapping. Development-time local recording or offline synthesis may produce drafts; no paid/cloud voice service or generated pronunciation is implicitly approved. Every final recording must pass listening review.

Offer an accessible switch to a reviewed visual spelling task from the correction family for learners unable to hear dictation, clearly labelled as a different task and selected/reserved using that family's pool. Do not display the target transcript and count it as independent dictation. If the alternate pool is exhausted, shorten the session or offer labelled review. Audio load/playback failures allow retry or this alternative; they do not score a wrong answer.

Own one session audio player behind `AudioPromptPlayer`: play approved asset, stop, state/error stream, dispose. User gesture starts playback; rapid replay replaces/stops earlier playback. Stop on navigation, background/inactive state, interruption and reset; return idle on resume and require a new Play action. Cancel subscriptions and dispose at session end. Test no overlap, interrupted loading, repeated taps, route disposal, background/foreground and actual native audio. Browser autoplay policies and browser success are not Android evidence.

### Local privacy and future synchronization

Propose no account, advertising, analytics SDK, student name, date of birth, school, cloud upload or background data collection. Parent summaries stay on device; the parent feedback route opens an explicitly approved destination manually and attaches no learner data. If no destination is supplied, provide a parent-visible copyable app version and verbal feedback guidance without transmitting anything. Research consent, recruitment and remote aggregation remain later decisions.

Disable Android cloud backup/device-transfer of the learner database using platform-appropriate manifest and backup/data-extraction exclusions, and verify packaged configuration on supported Android versions. This is part of making “saved on this device” accurate; OS settings must not create an accidental cloud copy. Release logs omit learner responses and progress payloads. Removing release Internet permission is preferred if the approved implementation has no network dependency; verify the merged release manifest and plugin behavior.

Local-only storage has no remote acknowledgement/outbox/conflict policy because no sync runs in this pilot. Future Firebase work must separately approve identity/ownership, source-of-truth rules, durable queue and acknowledgement, idempotency, conflicts, deletion propagation, account switching, regions, retention, server-side authorization and Android/iOS/Web persistence. Do not claim the current schema proves sync readiness or that deletion propagates to a nonexistent cloud copy.

## Consequences and verification

The Web adapter keeps agent checks fast but loses progress on refresh and cannot validate SQLite. Device-only progress and a finite reviewed bank constrain the pilot, deliberately and visibly. Content review and real-device availability may block release even after software checks pass. Use the [execution plan](../../development/pilot-execution-plan.md) for coverage and ownership.

Recommend Android API 24+ phones/tablets for this pilot, portrait and landscape, plus current installed Chrome for QA. Current Flutter documentation lists Android API 24–37; verify the selected Flutter SDK and resolved plugins before fixing the manifest minimum. Record the tested upper OS versions rather than implying every supported version was executed. [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms)

Mandatory checks cover pure scoring/selection, content and asset/review validation, Android first launch/import/update/migration/force-stop durability, input/Back/rotation/lifecycle, local reset, real phone and tablet offline/audio/accessibility, profile/release performance, APK/AAB readiness and independent review. An Android emulator is additional native evidence, not a replacement for the required phone/tablet checks. No check described here has been executed for an app that does not yet exist.

## Approval

No approval is recorded. The user must approve the pilot scope, these library/state/navigation/storage/privacy choices, all 22 families with 440 reviewed questions, device/check boundaries and the finalized executable check contract. The recommended API baseline and device-only backup behavior are included in that approval. Git initialization and creation of a named development branch require separate explicit authorization under AGENTS.md. Uploading or publishing any build, provisioning Firebase and collecting research data require their own later approval.
