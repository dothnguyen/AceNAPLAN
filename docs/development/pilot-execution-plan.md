# Android pilot and Windows PC evaluation execution plan

Visual reference: the user-selected `design/AceNAPLAN.html`, mapped to scope in `docs/product/pilot-design-reference.md`. UI tasks must use its phone/tablet home, question and parent-summary compositions with the documented untimed eight-question flow and practice-only reporting adaptations. Include actual screenshots in visual QA evidence.

Status: **Approved implementation plan, scope revision 2 — 13 October 2026; checks still require current phase evidence**
Date: 2026-10-13 (Australia/Brisbane)
Scope: [PILOT-01–11](../product/pilot.md)
Architecture: [proposed ADR 0002](../architecture/adr/0002-android-pilot-implementation.md)
Coordinator contract: [autonomous execution](autonomous-execution.md)

## Decision packet

The base Android pilot was approved by the user. Scope revision 2 adds a resizable Windows PC evaluation build and explicit Windows layout/integration/build checks. The pilot still targets all 22 candidate families and 440 reviewed items, 20 bundled spelling recordings, mixed/topic practice, Android `sqflite`, shared pure Dart rules, `ChangeNotifier`, constructor injection, built-in `Navigator`, a visibly temporary in-memory Windows/Web repository, `audioplayers` for local assets, and deterministic Flutter painters/widgets. Firebase sync, accounts, cloud learner-data backup, analytics, paid/external generation, Flame games and public Web/iOS releases remain deferred under the recorded decisions.

Scope and check-contract approvals are recorded together with revision history in the pilot board. The Lead owns the board and progress file; this plan neither modifies them nor grants approval. Run the single supervisor for phase coordination. Current per-check evidence is in `.autonomy/evidence/pilot/`.

## Proposed family catalogue

Every family contains ten introductory and ten developing items, subject to educator confirmation of age/skill suitability. Composite quotas below total 20; they do not create additional 20-item families. All answers use the bounded response engine. Curriculum links must be checked against current official ACARA/Australian Curriculum sources during authoring; proposed family names do not establish alignment or comprehensive NAPLAN coverage.

| ID | Topic/area and family | Proposed internal mix / stimulus | Response |
| --- | --- | --- | --- |
| N-PV-01 | Place value: highlighted digit value | 10 whole-number and 10 decimal examples with explicit place boundaries | Numeric |
| N-PV-02 | Place value: compare/order values | 10 compare and 10 select a correctly ordered list | Single choice |
| N-OP-01 | Operations: addition/subtraction context | 10 addition, 10 subtraction; distinct problem structures | Numeric |
| N-OP-02 | Operations: grouping/sharing | 10 equal groups, 10 sharing/division; whole answers | Numeric |
| N-FD-01 | Fractions: fraction of collection | 10 described sets, 10 visually grouped sets; integral outcomes | Numeric |
| N-FD-02 | Fractions/decimals: representation/equivalence | 10 equivalent representations, 10 fraction–decimal matches | Single choice |
| N-PA-01 | Patterns: unknown number sentence | 10 additive and 10 multiplicative relationships | Numeric |
| N-PA-02 | Patterns: continue stated sequence | 10 increasing and 10 decreasing; rule explicitly unambiguous | Numeric |
| N-MT-01 | Measurement/time: elapsed time | 10 within-hour, 10 crossing-hour; no ambiguous date rollover | Numeric with displayed unit |
| N-MT-02 | Measurement: scaled instrument | 10 length and 10 capacity; generated readable scale and units | Numeric with displayed unit |
| N-SP-01 | Space: locate grid reference | 10 identify a cell, 10 follow a stated location instruction | Single choice |
| N-SP-02 | Space: compare angle with right angle | 7 smaller, 6 equal, 7 larger; explicit reference and clear diagrams | Single choice |
| N-DT-01 | Data: scaled graph reading | 10 direct values and 10 differences; labelled axes and steps | Numeric |
| N-DT-02 | Data: compare table values | 10 comparisons and 10 differences | Single choice or numeric, explicitly typed per item |
| N-CH-01 | Chance: likelihood from collection | 10 compare events and 10 identify most/least likely | Single choice |
| N-CH-02 | Chance: possible/certain/impossible | 7 possible, 7 certain, 6 impossible; everyday unambiguous situations | Single choice |
| C-SP-01 | Spelling: contextual audio dictation | 20 distinct target words/context recordings; no names or homophone ambiguity | Spelling entry |
| C-SP-02 | Spelling: correction in context | 20 distinct target words and reviewed misspellings | Spelling entry |
| C-GR-01 | Grammar: subject–verb agreement | 10 singular and 10 plural contexts, varied sentence structures | Sentence choice |
| C-GR-02 | Grammar: sentence completion | 8 tense, 6 connective, 6 appropriate word | Sentence choice |
| C-PU-01 | Punctuation: sentence boundaries/capitals | 10 end-mark/boundary and 10 capital-letter decisions | Sentence choice |
| C-PU-02 | Punctuation: apostrophes | 10 contractions and 10 possession contexts | Sentence choice |

Family exploration may refine parameters, distractors and examples within these bounds. Splitting/adding a family, changing counts or significantly changing curriculum/difficulty boundaries requires scope revision before dependent bulk authoring. Publish the approved catalogue as machine-readable configuration during implementation; validators compare the release bank against it.

## Content production and release gate

Keep editable authoring templates and draft data outside the release asset directory. Generate drafts offline during development with deterministic scripts and explicit seeds, then run schema, count, uniqueness, variation, arithmetic/key, distractor, explanation and asset checks. No model/service is called by the installed app. Meaningful variation must change relationships, representations, wording/structure or misconception coverage; option shuffling and name substitutions alone do not satisfy it.

For every question require a stable item/variant/family ID, immutable revision, difficulty, skill/curriculum reference, provenance/rights, answer rule, constructive hint/explanation, accessible stimulus and reviewer record bound to its content digest. For every dictation recording require an approved transcript, playable asset/digest, target/context mapping, rights and listening review. A spelling text fixture does not prove pronunciation. Do not synthesize or assert an educator's approval.

An independent educator/content reviewer must inspect all 440 final questions and 20 recordings, including mathematical answer keys, misleading distractors, language ambiguity, age suitability and accessibility equivalents. Automated/template review reduces errors but does not replace that sign-off. Record reviewer identity/qualification as agreed by the user, date, reviewed hashes, findings and resolutions in a local release evidence file. Changed content invalidates the affected approval. Release validation fails on drafts, missing assets, absent/stale review, wrong counts or duplicate/invalid IDs.

No educator or recording capability is assumed available. Work may produce software and draft assets under approved implementation scope while those gates are blocked; it cannot call the complete pilot released or phase-complete with unreviewed content. If offline synthesis is unavailable, keep a precise missing-audio list for authorized recording rather than adding an external service.

## Epics and file ownership

These are proposed task groups; the Lead translates them into bounded tasks after approval. Dependencies and acceptance risks govern sequencing. Shared manifests, schema migrations and package lockfiles are integrated serially by the Lead. At most three specialists work concurrently with disjoint permitted files; independent reviewers do not edit implementation.

| Epic | Requirements | Dependencies | Primary ownership and acceptance |
| --- | --- | --- | --- |
| P00 Foundation | 01, 02, 06, 11 | Approved scope/ADR/contract, Git/branch and toolchain | Lead + Flutter developer: Android/Windows/Web shell, pinned dependencies, composition, responsive phone/tablet/window layouts, no-account startup, test-adapter labels and native-release guard |
| P01 Domain/content | 03, 04, 05, 09 | P00 contracts | Flutter/domain implementation with educator review: schema, all 22 families/templates, 440 draft then approved items, exact scoring, provenance, accessible stimuli and audio manifest |
| P02 Android persistence | 06, 09 | P00, P01 schema | Bounded storage implementer: SQLite schema/migrations, atomic importer, immutable revisions, restart recovery, reset, backup exclusions; Lead owns migration ordering |
| P03 Session selection | 02, 05, 10 | P01 rules, P02 transaction contract | Flutter/domain developer: deterministic quotas, distinct unseen items, atomic reservation/presentation/help/submission, resume, exhaustion and labelled review |
| P04 Practice experience | 01, 02, 03, 05 | P01 widgets, P03 | Flutter developer: input, hints/explanations, keyboard/Back, audio lifecycle/errors and accessible alternatives; actual Android/Web behavior |
| P05 Parent/local summary | 07, 08 | P02, P03 | Flutter developer: independent/helped/review totals, sample-size caveat, deterministic next-topic rule, local reset and parent feedback with no automatic data upload |
| P06 Verification/candidate | All | P00–P05, content/audio approval, target access | QA + independent reviewer: final revision evidence, phone/tablet and Windows checks, Android release candidate, documented limitations and release readiness; no upload |

For the next-topic rule recommend the practiced topic with the lowest independent correct fraction once it has at least five independent attempts; break ties by fewer attempts then stable topic ID. With fewer than five attempts, state “A small sample — try more practice,” and recommend the least-practiced available topic using a stable tie-break. Helped/review attempts never inflate that fraction. This is practice guidance, not proficiency assessment. Cover these exact rules in P05 unit tests.

Backend role work, if used, is bounded to the approved local persistence contract; it does not imply Firebase implementation. Confirm configured models are actually launchable before assigning any role; an unavailable QA model is a reported capability blocker, never a silent substitute.

## Mandatory check intents

The revised executable contract defines 17 concrete check IDs and argument arrays, including Windows desktop integration, build and responsive-layout checks. The following intent names are coverage requirements, not claims that all scripts exist or that commands have run. Named tests and `scripts/verification/pilot_gate.py` are implementation deliverables; they must independently execute checks or validate genuine, revision-bound evidence before any gate can pass. Missing/unavailable evidence fails closed. No dummy success command or browser-only replacement satisfies native checks.

| Check intent | Required evidence |
| --- | --- |
| Format/static | `dart format --output=none --set-exit-if-changed` over agreed source/test/tool paths; `flutter analyze`; resolved SDK/package versions |
| Content release validation | Exactly 22 known families × 20 approved items; immutable IDs/revisions; 10+10 difficulty counts; internal family mix; meaningful variation/duplicate checks; assets and review hashes |
| Scoring/templates | Pure tests for every family, boundary examples, numeric units/equivalence, spelling normalization, single correct choice, invalid-input exclusion, hints/retries and explanation consistency |
| Selection | Exact/fallback quotas; all-new vs review labels; exhaustion; identical consecutive set prevention when alternatives exist; abandonment; reservations/exposure/help; same seed; saved resume; content update/retirement; alternate spelling pool |
| Android repository | Real SQLite first import/idempotence/rollback, partial import, schema migrations, active-set update, pinned revisions/assets, duplicate submission, write errors, local reset and historical progress |
| Widget/accessibility | Session/summary flows, error/retry/loading, large text, semantic names/focus, visible units and readable stimuli, portrait/landscape sizes, assisted/review totals |
| Browser flows | Chrome version + memory adapter identity, keyboard navigation and complete shared flows at phone/tablet sizes; refresh reset is expected and visible |
| Windows PC evaluation | Native Windows integration launch, visible in-memory test warning, portrait-proportioned and landscape-proportioned layouts; progress resets on exit |
| Windows PC evaluation | Native Windows integration launch, visible in-memory test warning, portrait-proportioned and landscape-proportioned layouts; progress resets on exit |
| Android integration | Device/emulator ID + OS + build mode + SQLite adapter, force-stop/relaunch, rotation, keyboard/insets/Back, background/resume, interruption, offline/audio and upgrade with retained progress |
| Real phone | Model/OS/build hash, physical installation/update, offline first use and resume, touch/audio/TalkBack, keyboard, portrait/landscape, local summary/reset and profile/release performance |
| Real tablet | Same evidence independently on a representative physical tablet; browser resizing/emulator evidence does not satisfy this gate |
| Build/privacy | Debug/installable APK for automated validation and release APK/AAB readiness; release manifest permissions/backup exclusions, no analytics/network collection/secrets, licenses and approved assets |
| Human educational approval | Complete question/audio review bound to final hashes by a person; open content defects block completion |
| Independent final review | Actual reviewer report over final source/content fingerprint, resolved blocking findings and refreshed review after material fixes |

For native scripted checks use an explicit target ID and report Flutter/Android versions; never allow automatic selection to turn an intended Android check into Chrome. Scripts must return nonzero on unavailable targets. Evidence validators check actual referenced logs/artifact/review hashes and required fields; they do not create device or human observations. A signed distributable candidate may need the user's existing upload key; document that blocker and keep secrets out of Git. Debug signing is not production signing readiness.

Device performance evidence includes measured cold-start-to-ready and question-transition durations plus frame timing/jank in profile/release on each representative device. Propose target cold start ≤3 seconds after seeded launch and ordinary question transitions ≤300 ms without blocking input; record first-import time separately. Measure at least five cold starts and a complete eight-item session per device, report range and worst case, and investigate repeated frame stalls. Targets are proposed acceptance criteria requiring contract approval, not measurements.

## Execution and completion

After explicit approval, record exact scope/contract digests, branch, PILOT-01–11 and check IDs using the revision approval workflow, preserving earlier approvals. The supervisor's OS lock remains the single-runner gate. The invoking chat monitors; its resumable supervised Lead coordinates. Only the Lead updates board/progress, and only the supervisor accepts completed candidates after actual check execution and evidence validation.

Implement foundation and a small domain/storage vertical slice first to expose seeding/resume risks; the release bank remains gated until every family and review passes. Parallelize independent content authoring and UI work only after their contracts are stable. QA/review findings become linked defects; fixes rerun affected checks and receive fresh review where needed. Bind reports to the actual revision/content fingerprint.

Completion requires all eleven requirements, mandatory checks, reviewed bank/audio, usable Windows evaluation, real Android phone and tablet evidence, current independent implementation review, and a release-candidate record. Tool absence, educator availability, missing device/signing access or a runtime limit remains visible unfinished work. A successfully generated APK, browser test, Windows build, drafted bank or completed subtask does not waive a remaining gate. Play upload/publication and the market experiment are separately authorized operations.
