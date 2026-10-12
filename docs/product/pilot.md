# Proposed Android MVP pilot: short practice and useful feedback

Status: **Approved for implementation — 13 October 2026**.
Suggested phase parameter: `pilot`.
Date: 12 October 2026 (Australia/Brisbane).

The user approved the phase scope and requested development on 13 October 2026, following the concrete prerequisite packet in `docs/development/pilot-start-decisions.md`. Implement using `design/AceNAPLAN.html` and the pilot adaptations in `docs/product/pilot-design-reference.md`. Android is the first product release; Web is a supporting agent verification target. The existing `mvp` board entry and `mvp.md` remain unchanged. Publication remains a separate approval.

## Goal and hypothesis

Test whether Year 4/early Year 5 children willingly return for short Numeracy and Conventions practice, and whether parents find the explanations and practice summary useful enough to continue using the product. Do not claim full NAPLAN preparation or score prediction.

Suggested promise: “Short Year 5 maths and language practice, with explanations that help your child understand mistakes.” Learning is the product; official test familiarity is supporting context.

## Release boundary

Build the pilot as a Flutter Android app for phones and tablets, with portrait and landscape layouts. Use the user's existing Google Play developer account for an internal testing release, followed by a parent/child closed pilot where appropriate. Creating a release candidate does not authorize uploading or publishing it. iOS remains a later release target; Web supports rapid agent verification rather than a public product release in this phase. SQLite remains the local store, and Firebase remains the intended backend for later synchronization.

Bundle the reviewed question bank, explanations and spelling audio with the Android pilot so that installed practice works offline without a Firebase connection. Validate real Android SQLite save/restart/migration behavior, activity/app lifecycle, input and audio on actual Android targets. Profile performance in a profile/release build on a representative device; browser smoothness and debug-mode measurements do not establish Android performance.

Keep scoring and learning rules in shared Dart code and isolate persistence/platform services behind small testable contracts. Agents can run the same screens and flows in Chrome using a clearly identified test repository (in-memory if sufficient), without requiring production Web SQLite in this phase. Such runs verify shared UI/domain behavior only. They must not be counted as Android SQLite, durable persistence, native plugin, lifecycle, or release validation. Avoid building a separate browser product merely to obtain a testing surface.

Deferring cloud progress synchronization is an explicit proposed change to the earlier MVP proposal. Display “progress is saved on this device”; do not imply cross-device recovery. Firebase provisioning, cloud data collection, parent identity and synchronization require their later approval. No student names, dates of birth, school names, essays or cross-device identifiers are required for this local pilot.

## Proposed requirements

| ID | Feature | Acceptance criteria |
| --- | --- | --- |
| PILOT-01 | Immediate practice | An installed Android app reaches practice without an account; one local learner profile; no unsolicited personal information required. Clear intended audience and independent-product wording. |
| PILOT-02 | Short sessions | Offer an eight-question mixed session and topic practice; untimed by default; pause/exit saves completed attempts. Phone/tablet portrait and landscape, touch, soft keyboard, and Android Back behavior work; browser/keyboard checks supplement these. No compulsory speed mode. |
| PILOT-03 | Bounded response engine | Single choice, numeric entry, spelling entry and sentence-based grammar/punctuation choices. Numeric equivalence/units and spelling normalization are explicit. Complex drag/grid/hot-spot/multi-select engines are deferred. |
| PILOT-04 | Topic/family question bank | During pilot implementation, explore and select multiple learning question families for each included Numeracy topic and Conventions area, then generate at least 20 distinct reviewed questions per selected family. Total size is 20 × approved family count, replacing the earlier fixed 120-item proposal. Every item has skill/curriculum metadata, answer rules, useful explanation, version/provenance and review approval. Spelling dictation includes reviewed audio and an accessible alternative. See the candidate matrix below; selection and generation are future pilot work, not authorized by this planning document. |
| PILOT-05 | Explain and retry | Explain why an answer works, provide an actionable hint, and offer practice with another item. Record hinted/repeated versus independent first attempts separately. Audio failure does not silently reveal the answer or count an invalid attempt as incorrect. |
| PILOT-06 | Durable local progress | Android SQLite stores item versions, attempts and sessions. Force-stop/relaunch preserves completed work; rotation/background/resume does not duplicate or discard attempts. Test partial sessions, local reset, migrations and offline operation with bundled content/audio. Surface storage/audio errors; make local-only persistence limitations clear. Web test-repository results do not satisfy this requirement. |
| PILOT-07 | Useful parent summary | Show sessions, topics, independent correct/attempt counts, help use and a recommended next topic. Small evidence samples are explicitly identified. No official proficiency labels, rankings, diagnosis or predicted NAPLAN score. |
| PILOT-08 | Pilot feedback | Offer a parent-directed feedback route outside the child's practice. Use only explicitly approved aggregate/local session measures; no third-party analytics SDK or cloud collection is implied. Obtain consent and data-handling approval before any research-data upload. |
| PILOT-09 | Content generation and SQLite seeding | Implement the authoring schema and approved family templates; generate 20 questions per family offline during development; validate counts, meaningful variation, duplicates, scoring, curriculum links and assets; obtain educational review; bundle only approved content/audio. Seed Android SQLite atomically and idempotently on first launch, safely recover interrupted imports, and apply versioned content updates without deleting progress or breaking historical attempts. Draft/unreviewed items, missing audio and invalid assets must fail the release gate. No live AI generation during learner practice. |
| PILOT-10 | Fresh practice-set selection | Persist learner exposure and reserved-session item IDs in SQLite. Select distinct unseen eligible items across the chosen topics/families, with an explicit topic/difficulty mix, and avoid identical consecutive sets. Resume a paused session without regenerating its set. When the eligible unseen pool is too small, offer a shorter fresh session or clearly labelled review; never silently describe repeated questions as all new. Test exhaustion, interrupted sessions, restarts, reservations, content updates and separation of review from independent first attempts. |

## Question-family exploration and generation (future implementation)

A **topic** is the learning area, such as fractions. A **question family** is a distinct skill/problem pattern within it, such as finding a fraction of a collection. A **response format** is the interaction, such as multiple choice or numeric entry. The target is 20 questions per learning family, not 20 questions shared across an entire response format. Several families can reuse the same small set of widgets.

Explore the following candidate matrix during phase planning. Choose the final families and curriculum/difficulty boundaries before bulk generation. This catalogue is proposed breadth, not full curriculum coverage or a bank of authored questions.

| Numeracy topic | Candidate family A | Candidate family B | Questions if both selected |
| --- | --- | --- | --- |
| Place value | Value of a highlighted digit | Compare/order number values | 40 |
| Operations in context | Addition/subtraction word problems | Equal grouping/sharing with multiplication/division | 40 |
| Fractions and decimals | Fractions of collections | Fraction/decimal representations and equivalence | 40 |
| Patterns and unknowns | Missing values in number sentences | Continue a sequence with a defined rule | 40 |
| Measurement and time | Elapsed-time problems | Read a scaled measuring instrument | 40 |
| Space | Locate an object using a grid reference | Compare an angle with a right angle | 40 |
| Data interpretation | Read values from a scaled graph | Compare values in a table | 40 |
| Chance | Compare likelihoods from a simple collection | Identify possible/certain/impossible events | 40 |

| Conventions area | Candidate family A | Candidate family B | Questions if both selected |
| --- | --- | --- | --- |
| Spelling | Contextual audio dictation | Correct a misspelled word in context | 40 |
| Grammar | Subject–verb agreement | Complete a sentence using the appropriate tense/connective/word | 40 |
| Punctuation | Sentence boundaries, end marks and capitals | Apostrophes for contractions/possession in context | 40 |

Selecting all candidates gives **16 Numeracy families × 20 = 320 questions**, plus **6 Conventions families × 20 = 120 questions**, for **440 total**. A smaller approved topic selection remains possible for quick shipping; the 20-per-family requirement still applies. Composite families must specify their internal mix: 20 combined addition/subtraction problems does not mean 20 for each operation. If exploration splits a family into separately selected types, each new family needs its own 20-question set.

Meaningful variation changes mathematical values/relationships, representations, contexts, target words, sentence structures or misconceptions; renaming a character or shuffling options alone is not enough. Each family defines its parameter constraints, valid answers, distractor rules, accessible stimuli, explanations and difficulty progression. Deterministic mathematical variants are allowed after template validation; language variants need sentence-level review. Keep source/draft data separate from release content. This planning update does not generate questions or implement an authoring pipeline.

## Fresh sessions and finite-bank limits

Prefer unseen items rather than merely shuffling the same questions. Log exposure when a question is presented, not only when answered; reserve selected item IDs for an active session and prevent duplicate submissions. Store stable content/variant IDs across updates so a corrected explanation does not make an already-seen question appear new. Review attempts remain distinguishable from independent first attempts. Local-only history applies to this learner/device; it cannot guarantee cross-device novelty before synchronization exists.

A topic with two 20-question families contains 40 questions, allowing five entirely unseen eight-question topic sessions if all items are eligible. For the full proposed 320/120 bank, an eight-question mixed session with four Numeracy and four Conventions items has at most 30 entirely unseen sessions before the smaller Language pool runs out; prior practice, difficulty filters and per-family quotas can reduce that number. These are capacity examples, not promises of unlimited novelty.

On exhaustion, offer fewer unseen questions, an explicitly labelled review session, or a later approved content expansion. Do not silently repeat items, fabricate unvalidated variants, reset history, or introduce runtime AI to fulfil an “always new” claim. Planned content replenishment can expand the pool in later approved updates; freshness must remain testable and honest.

## Explicitly deferred

Reading passages and Writing Studio; official-style full-length simulation; official-level prediction; live AI; advanced adaptation; accounts/cross-device sync; custom Flame mini-games/adventure map; social features; notifications; subscriptions/payments; printable worksheets; iOS/public Web release; production Play Store rollout. Preparing an Android release candidate is included; uploading to any testing/production track needs explicit authorization. Flame remains available for a later phase when a game adds educational or retention value.

## Build and release checks

Approve concrete command mappings later for formatting, static analysis, per-family question-count/content validation, answer/template correctness, duplicate/variation checks, seed/update/migration recovery, fresh-set selection/exhaustion, widget/accessibility tests, shared browser flows, Android integration tests, APK/AAB builds, and real-device smoke checks. Require educator content sign-off and independent implementation review. Keep separate check IDs and evidence for shared/browser versus Android/native behavior. Record device, Android version, build mode, browser and persistence adapter for each applicable check.

| Verification layer | Required coverage |
| --- | --- |
| Shared Dart/unit/widget | Scoring, normalization, question validation, feedback, session/progress rules, loading/error states |
| Browser agent checks | Shared app navigation, answer/hint/retry flows, parent summary, phone/tablet-sized layouts and basic accessibility; identify any test adapter |
| Android emulator | Real SQLite, keyboard/insets, Back, rotation, background/resume, audio and offline sessions; integration automation where tooling supports it |
| Real Android device | At least one phone and one tablet representative of the pilot, installation/update with progress preservation, cold start, offline use, touch/audio and profile/release performance |
| Release candidate | Android App Bundle/build/signing readiness, approved content, reviewed results and known limitations; no secrets committed or publishing implied |

Flutter provides integration testing on devices/emulators and in browsers; platform runs remain distinct evidence. [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)

Start distribution through Play internal testing, then a targeted closed pilot. Account-specific production access requirements must be checked in the user's Console. Personal accounts created after 13 November 2023 currently require at least 12 continuously opted-in closed testers for 14 days before applying for production access; merely owning an account does not establish whether that condition applies. [Google Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en), [testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)

Technical completion means all approved acceptance/check gates pass and an Android release candidate is ready. A passing browser test cannot waive a required Android check. Store upload/publication is a separate explicit approval. Market validation is a separate pilot outcome: implementing the app cannot establish demand.

## Suggested two-week market experiment

Recruit about 20 Android-owning parent/child pairs, including both phone and tablet users; observe five first sessions, then allow two weeks of ordinary use. Device availability is a pilot eligibility criterion, not an assumption about all children. Provide accessible alternatives and avoid turning participation into high-pressure testing. The sample is qualitative/product research, not a representative educational trial. A market experiment and any Play account production-access test have separate success criteria.

Proposed go/no-go signals (hypotheses, not industry benchmarks):

- At least 15 of 20 pairs complete a first session with minimal onboarding help.
- At least 8 of 20 complete three sessions on separate days during the pilot without repeated personal prompting. Record the recruiting/contact procedure so “return use” is interpretable.
- At least 10 of 20 parents can explain one useful takeaway from the summary and want continued access.
- No unresolved wrong answer key, misleading explanation, serious accessibility defect or data-loss issue.

Ask parents what they would pay and which feature would justify it; stated willingness is weaker evidence than a later voluntary paid offer. Do not add checkout to this phase just to collect a vanity conversion number. Compare error reduction on new similar items cautiously; repeated answers are not proof of learning or future NAPLAN improvement.

If return use is weak, revise content/session/feedback before investing in maps, AI or another platform. If use is strong but parents ask for reading or multiple-device history, make that the next phase using the same phase runner.

## Approval before execution

Review the [PRD audit](prd-review-2026-10-12.md), finalize Android storage, the browser test-adapter boundary, supported devices/Android versions and the remaining content requirements, approve the scope/ADRs and actual check contract, and authorize the development branch. The `pilot` phase is already registered after the user's development request. Once its prerequisite decisions are approved and recorded, launch the existing supervisor against this phase; there is no need to repeat the phase request. Creating this document does not grant prerequisite approvals or start application code.
