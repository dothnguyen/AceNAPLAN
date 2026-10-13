# Pilot design reference

Source: `design/AceNAPLAN.html`, selected by the user on 13 October 2026. Use this visual reference for native Flutter implementation and preserve the original export.

## Visual direction

The export contains phone and tablet versions of Student Home, Year 5 Question, Reading Passage and Parent Analytics. Its 390px phone and 1180px tablet widths are comparison sizes, not fixed app dimensions.

Carry through cream surfaces (`#FFFBF2`), navy text (`#1F2A44`), muted text (`#5A6178`), rounded cards, spacious question layouts and subject accents: Numeracy blue (`#1D6FD1`) and Conventions amber (`#B45309`). The source uses Plus Jakarta Sans; bundle appropriately licensed font assets if available and verify provenance. Offline operation must not depend on network fonts. Maintain accessible contrast, touch targets and text scaling.

Adapt compact phone navigation and wider tablet compositions responsively. For Windows evaluation, let users resize the app window into a tall portrait-proportioned shape or a wide landscape-proportioned shape; keep the same app routes and content usable in both. Recreate the design in Flutter widgets and local stimuli renderers; the HTML is a reference rather than the app runtime.

## Pilot screen mapping

| Design element | Pilot adaptation |
| --- | --- |
| Home / Your Journey | Numeracy and Conventions entry points; progress calculated from actual local attempts. |
| Four subjects / ten-minute daily practice | Eight untimed questions in the selected pilot domain; labels match actual behaviour. |
| Question 4 of 25 / countdown / Flag | Actual position out of eight, no countdown; approved submit, feedback, hint and next flow. Flagging is outside scope. |
| Fraction-grid question | Reuse the composition with actual bank content and required response type. The sample is not automatically an approved item. |
| Reading / Writing / Mock Tests | Future reference; omit active pilot navigation for these features. |
| Named learner / Parent Analytics | Local anonymous learner summary using genuine history; omit the sample child's name. |
| NAPLAN proficiency / readiness | Practice accuracy, attempts, hints and topic coverage; no conversion to official NAPLAN levels. |
| Generate practice sheet / adaptive recommendation | Outside current scope. |
| Sample streak, level and completion values | Omit unsupported counters; retained values must reflect implemented local behaviour. |
| PC evaluation target | Run a native Windows desktop build with a visible temporary-test-data banner. Use portrait and landscape window proportions; progress clears when the app exits. |

## Verification

Compare implemented home, question and parent-summary screens with phone/tablet references. Capture actual screenshots and record deliberate pilot adaptations. Check phone/tablet rotations, Windows portrait-proportioned and landscape-proportioned resizable windows, narrow widths, large text, long content, keyboard entry, audio controls, feedback and empty history. Browser screenshots support visual QA; Windows desktop launch and Android checks remain distinct and mandatory. Appearance alone cannot satisfy functional, content or device gates.
