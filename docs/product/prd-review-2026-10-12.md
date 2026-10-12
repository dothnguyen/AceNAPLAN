# PRD review: curriculum alignment and a shippable pilot

Reviewed: 12 October 2026 (Australia/Brisbane).
Status: Recommendations, not approval to change scope or implement the app.
Input: `plan/naplan_quest_year_5_prd.md` and the existing proposed `docs/product/mvp.md`.

## Assessment

The draft is a useful long-term topic inventory. It needs stronger assessment accuracy, a curriculum coverage matrix, separate learning/familiarisation modes, and a smaller first release. Replace “Complete Syllabus”, “Full Syllabus”, and “NAPLAN-Accurate” with bounded claims supported by reviewed content. The proposed positioning is: independent, curriculum-linked Year 5 literacy/numeracy practice with short sessions, useful explanations, and visible practice progress.

The original PRD and current phase board are unchanged. The separate `pilot.md` is a concrete suggested MVP, still Proposed. Neither the review nor that proposal authorizes implementation, provisioning, publishing, or deployment.

## Assessment facts to correct or clarify

| PRD section | Finding | Suggested change |
| --- | --- | --- |
| 1–2: alignment | NAPLAN currently draws on skills shared by curriculum v8.4/v9 while jurisdictions transition; assessed learning mainly precedes the test year, with some later material | Use v9 content mappings, retain relevant v8.4 crosswalks, and distinguish prerequisite/core/challenge rather than treating the Year 5 end-of-year standard as the March baseline. [NAP curriculum alignment](https://www.nap.edu.au/naplan/whats-in-the-tests) |
| 2: durations | The draft's 42/50/45/50 minutes are correct | Retain them for standard online simulations, separately from untimed learning. Recheck annual administration guidance before release. [Official test durations](https://www.nap.edu.au/naplan/key-dates/naplan-test-window) |
| 2: item counts | Current framework specifies Year 5 Reading 39, Conventions 52 (25 spelling, 27 grammar/punctuation), Numeracy 42 | Replace approximate ranges; the numeracy 35–40 estimate is incorrect. [Framework, Tables 2–4](https://www.nap.edu.au/docs/default-source/naplan/naplan-assessment-framework.pdf) |
| 2–3: spelling | Audio dictation is absent from the draft | Add replayable sentence/word audio plus proofreading; provide a separately labelled accessible alternative rather than revealing the correct word through a transcript. [Framework, section 2.4](https://www.nap.edu.au/docs/default-source/naplan/naplan-assessment-framework.pdf), [demonstration alternatives](https://www.nap.edu.au/naplan/public-demonstration-site) |
| 3B: writing rubric | Criterion four differs by genre: narrative uses Character and setting; persuasive uses Persuasive devices. Cohesion and Paragraphing are separate criteria | Correct the combined rubric; do not duplicate paragraphing inside cohesion. Preserve distinct genre guides. [Framework, Tables 6–7](https://www.nap.edu.au/docs/default-source/naplan/naplan-assessment-framework.pdf) |
| 2: writing interface | Basic editing/formatting is defensible; a scaffolded editor is a teaching feature | Keep planning/help in learning mode; simulation suppresses hints, spelling/grammar checks and autocorrect. Bold/italic/underline are documented capabilities, so removing all formatting would be an unnecessary correction. Verify word-count/font/spacing parity against the current demo before advertising replication. [Editing FAQ](https://www.nap.edu.au/naplan/faqs/naplan--general), [keyboard controls](https://www.nap.edu.au/naplan/understanding-online-assessment/keyboard-shortcuts) |
| 4: proficiency dashboard | Official labels are real, but arbitrary app percentages cannot be translated directly to them; official reporting has five scales, including separate spelling and grammar/punctuation | Remove the direct-mapping promise. Report observations, attempt counts, assistance and next practice skills. Future readiness estimates need calibration evidence, not a chosen percentage threshold. [Reporting and scales](https://www.nap.edu.au/naplan/results-and-reports) |
| 4: adaptive tests | Official testing uses branching stages; difficulty contributes to results | A simple app practice recommender is useful but should not be described as reproducing official adaptive scoring. Separate future familiarisation from measurement claims. [Tailored tests](https://www.nap.edu.au/naplan/understanding-online-assessment/tailored-tests) |

The next published NAPLAN window is 10–22 March 2027. Design the pilot around the current Year 4 cohort preparing for early Year 5, with useful ongoing learning after the test season. [NAP key dates](https://www.nap.edu.au/naplan/key-dates)

## Mathematics coverage changes

Use six v9 strands in metadata: Number, Algebra, Measurement, Space, Statistics, Probability. The earlier paired headings are convenient informal grouping, not the current strand structure. [ACARA Mathematics structure](https://www.australiancurriculum.edu.au/curriculum-information/understand-this-learning-area/mathematics)

| Topic | Recommended treatment |
| --- | --- |
| Multiplication/division | Foundation facts to 10 × 10 and related division (AC9M4A02); 11/12 facts optional. Teach arrays, grouping, inverse relationships and strategy choice instead of prescribing short division as the only method. Contextual remainders belong in the Year 5 bridge (AC9M5N07). [Final F–6 content](https://www.australiancurriculum.edu.au/content/dam/en/curriculum/ac-version-9/downloads/mathematics/mathematics-curriculum-content-f-6-v9.docx) |
| Fractions/decimals | Foundation: equivalence, number lines, fractions of collections, tenths/hundredths. Bridge: mixed numerals, related-denominator calculations and common percentage equivalences. Percentages are not exclusively Year 6. [Year 5 standard and AC9M5N03/05](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-5/ws03-representing-and-adding-fractions) |
| Factors and number properties | Keep odd/even reasoning in foundations; distinguish Year 5 factors/multiples from Year 6 prime/composite work. [Year 4 standard](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-4/ws02-number-addition-and-subtraction), [Year 6 standard](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-6/ws03-interpreting-and-comparing-data) |
| Measurement/time | Add interpreting scales, unlabelled intervals, temperature, estimation and reasonable units. Separate ordinary duration problems from later metric conversion/timetables. Year 5 includes 12/24-hour conversion and degree measurement. [Year 4](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-4/ws02-number-addition-and-subtraction), [Year 5](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-5/ws03-representing-and-adding-fractions), [Year 6](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-6/ws03-interpreting-and-comparing-data) |
| Shape/space | Retain maps, symmetry, transformations and shape reasoning. Concrete cube comparisons can be age-appropriate; do not turn them into a requirement for formal volume formulas. [Final F–6 content](https://www.australiancurriculum.edu.au/content/dam/en/curriculum/ac-version-9/downloads/mathematics/mathematics-curriculum-content-f-6-v9.docx) |
| Data | Prioritise tables, pictographs, scaled column graphs and interpretation. Year 5 introduces mode/line-graph work; range and pie-chart/media work need explicit later-extension justification. [Year 5 standard](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-5/ws03-representing-and-adding-fractions), [Year 6 standard](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-6/ws03-interpreting-and-comparing-data), [final F–6 content](https://www.australiancurriculum.edu.au/content/dam/en/curriculum/ac-version-9/downloads/mathematics/mathematics-curriculum-content-f-6-v9.docx) |
| Probability | Foundation: compare likelihoods, recognise dependence/independence and variation in repeated trials. Bridge: equally/unequally likely outcomes. Numerical fractional/decimal/percentage probability is explicit Year 6 content; do not make it the default starting point. [Year 4](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-4/ws02-number-addition-and-subtraction), [Year 5](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-5/ws03-representing-and-adding-fractions), [Year 6](https://www.australiancurriculum.edu.au/resources/work-samples/mathematics/year-6/ws03-interpreting-and-comparing-data) |

Year-level placement is not evidence that a topic can never appear in NAPLAN. Use it to set teaching sequence and difficulty, alongside assessment guidance and reviewed items. Include reasoning, estimation and real-context problem solving across every topic, rather than making fluency speed the main outcome.

## English coverage changes

The PRD's genres and basic punctuation topics are useful. Add precise skills and short learning activities, not just longer tests:

- Reading: main idea and supporting details, inference with evidence, sequence/cause/effect, connections across a passage, vocabulary in context, comparison, fact/opinion and text purpose. Teach rereading, summarising and checking understanding. Use text-linked question sets so comprehension is actually assessed.
- Grammar: pronoun reference, articles, prepositional/adverb phrases, direct/reported speech, connectives and consistent tense in context. Complex sentences and dialogue punctuation are appropriate Year 4 foundations, not automatically extension.
- Spelling: sound–letter patterns, morphology, word families, origins and spelling generalisations, with a progression from common words to unfamiliar patterns. Avoid beginning every learner with irregular multisyllabic words.
- Writing: planning, linked ideas, audience/purpose, cohesion and short revision exercises before full timed writing. Add human-readable examples of improvement; do not equate elaborate vocabulary or word count with quality.

These priorities are grounded in [ACARA Year 4 English](https://www.australiancurriculum.edu.au/resources/work-samples/english/year-4/ws02-adventure-narrative) and the [final English sequence](https://www.australiancurriculum.edu.au/content/dam/en/curriculum/ac-version-9/downloads/english/english-scope-and-sequence-f-10-v9.docx). This is selected literacy preparation, not complete English coverage: the curriculum also includes oral, literary and multimodal learning. [English learning area](https://www.australiancurriculum.edu.au/curriculum-information/understand-this-learning-area/english)

## Missing product requirements

1. **Content contract:** stable ID/version, domain/subskill, curriculum code/version/year, prerequisite/bridge/challenge tag, stimulus/assets, response type, answer rules, units/tolerances, explanation, misconception/hint, rights/provenance, reviewer and approval date. A code must match the actual skill an item tests.
2. **Editorial gate:** original or licensed content; an educator checks alignment, answers, ambiguity, reading demand and feedback. Automated QA verifies schemas/scoring; it does not replace educational review. Check licences per asset instead of assuming public visibility permits reuse. [NAP terms](https://www.nap.edu.au/copyright)
3. **Scoring policy:** define numeric equivalents, units, case/whitespace rules, spelling-sensitive answers, multi-select handling, assistance and first versus repeated attempts. Training partial credit can be useful but must not be advertised as official scoring.
4. **Accessibility:** keyboard/touch operation, readable contrast/text, focus, alternatives to drag-only actions, audio replay and purposeful audio alternatives. Supportive teaching aids are separate from faithful simulation. [NAP accessibility](https://www.nap.edu.au/naplan/accessibility)
5. **Learning experience:** default untimed sessions, useful feedback after errors, voluntary retries and no punitive streak loss or public ranking. Reward effort and progress without hiding mistakes.
6. **Reporting honesty:** show what was practised and the amount of evidence. Separate helped/repeated answers from independent first attempts; small samples are not proof of mastery. Avoid predicted NAPLAN levels or diagnostic claims in the first release.
7. **Market evidence:** name the parent buyer, learning promise, activation/return measures and research process. Collect only approved minimal pilot data; ask parents about usefulness and willingness to pay, rather than optimising children's screen time.
8. **Architecture:** replace Flutter/Godot ambiguity and the 90/10 pipeline with the approved Flutter/Flame, SQLite-local/Firebase-sync direction. Keep rules/scoring independent of UI and services. Defer live AI feedback until educational validity, privacy, cost and failure handling are designed and approved.

## Recommended first phase

Following the user's Android-first preference, ship the [proposed pilot](pilot.md) as a Flutter Android phone/tablet app focused on Numeracy and Conventions of Language, short practice, explanations, local progress and a modest parent summary. Use Web as a supporting agent verification surface, not the initial public release. Use the official demonstration site as a familiarisation reference/link; its availability means interaction mimicry alone is a weak product proposition. [Official demonstration](https://www.nap.edu.au/naplan/public-demonstration-site)

Relative to the current proposed MVP, defer the adventure map, iOS/public Web release, AI, advanced adaptation and cross-device progress sync. Retain mandatory Android/native verification. These are proposed sequencing changes, not cancellation of the approved overall stack/platform direction. They require scope approval before the board or source-of-truth MVP document changes.

Android-first lets the pilot validate real device-local SQLite while the shared UI/domain logic remains browser-testable. Flutter's basic `sqflite` recipe targets Android/iOS/macOS; a clearly identified in-memory Web test adapter can avoid implementing production browser SQLite merely for agent UI checks. Browser tests do not prove Android persistence, plugins, lifecycle or performance. [Flutter SQLite guidance](https://docs.flutter.dev/cookbook/persistence/sqlite), [integration testing](https://docs.flutter.dev/testing/integration-tests)

After observing repeat use, add content/reading or a genuinely useful game according to evidence. Add account-backed Firebase synchronization when families need cross-device history. Writing coaching and paid features should follow validated content/feedback and explicit approval, not an arbitrary AI usage percentage.

## Research boundary

Sources were checked on the review date, including the December 2025 NAPLAN framework and final v9 ACARA curriculum downloads. Some indexed ACARA PDFs are 2021 consultation drafts; their AC9-looking codes were not used as final curriculum evidence. This review is a targeted audit, not a completed item-by-item curriculum map, test validation, legal compliance audit, or official endorsement.
