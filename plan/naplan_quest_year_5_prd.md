# Product Requirements Document (PRD)

## App Name: NAPLAN Quest: Year 5 Master

---

### 1. Overview & Vision
* **Product Name:** NAPLAN Quest: Year 5 Master
* **Target Audience:** Year 4 / early Year 5 primary school students (Ages 9–10) in Australia preparing for NAPLAN Online.
* **Core Goal:** Build a gamified, low-stress practice application that replicates online NAPLAN test interaction patterns (drag-and-drop, multi-select grids, split-screen reading, timed writing) while keeping learners motivated through adaptive difficulty, XP rewards, and clear diagnostic reporting for parents.

---

### 2. Year 5 NAPLAN Structure & Domain Breakdown

Year 5 NAPLAN assesses core skills mapped against the Australian Curriculum (v9.0) across four test sessions:

| Domain | Duration | Format & Question Types | Test Overview |
| :--- | :--- | :--- | :--- |
| **1. Writing** | 42 min | On-screen text editor with live word count, scaffolded prompt, and basic formatting controls. | Extended response based on a single prompt revealed on test day (Narrative or Persuasive). |
| **2. Reading** | 50 min | Split-screen interface (Passage on left, questions on right) with variable font/spacing controls. | 35–40 questions across short stories, informational reports, poems, advertisements, and persuasive pieces. |
| **3. Conventions of Language** | 45 min | Interactive drag-and-drop, multiple-choice, inline spelling correction, and text entry. | 50–55 questions evaluating contextual spelling, grammar rules, and punctuation accuracy. |
| **4. Numeracy** | 50 min | Multiple-choice, interactive grid inputs, drag-and-drop, and numeric text entry. | 35–40 questions covering Number & Algebra, Measurement & Space, and Statistics & Probability. |

---

### 3. Complete Syllabus & Topic Specifications

#### A. Conventions of Language (Spelling, Grammar & Punctuation)
* **Spelling:**
  * **Multi-syllable & Irregular Words:** Correcting misspellings of complex multi-syllable words and irregular phonetic patterns.
  * **Prefixes & Suffixes:** Root word transformations, adding prefixes (e.g., *un-*, *dis-*, *re-*) and suffixes (e.g., *-ing*, *-ed*, *-ful*, *-less*).
  * **Homophones & Confusables:** Identifying correct word choices in context (e.g., *there / their / they're*, *hear / here*, *accept / except*).
* **Grammar & Word Classes:**
  * **Sentence Structures:** Simple, compound (joined with coordinating conjunctions: *and*, *but*, *so*), and complex sentences (dependent clauses with *because*, *although*, *while*).
  * **Verb Tenses & Agreement:** Consistent past, present, and future tenses; subject-verb agreement across singular and plural nouns.
  * **Nouns, Pronouns & Modifiers:** Proper/common nouns, possessive pronouns (*his*, *hers*, *theirs*), comparative/superlative adjectives (*hotter*, *hottest*), and adverbs.
* **Punctuation:**
  * **Apostrophes:** Correct usage for contractions (e.g., *can't*, *it's*) and possessive nouns (singular: *the boy's dog*, plural: *the boys' dog*).
  * **Direct Speech:** Quotation marks, speech marks, and internal punctuation for dialogue.
  * **Commas & Enclosures:** Commas in lists, separating introductory clauses, and isolating direct address.

---

#### B. Writing Studio (Narrative & Persuasive Prompts)
* **Text Types & Prompts:**
  * **Narrative Writing:** Story planning, character arc development, setting description, plot orientation, complication, and resolution.
  * **Persuasive Writing:** Stating a strong position/opinion, structured arguments with evidence, persuasive language techniques (rhetorical questions, emotive words), and concluding summaries.
* **Official 10-Criteria Writing Rubric Alignment:**
  1. Audience engagement & tone
  2. Text structure & organization
  3. Ideas generation & relevance
  4. Persuasive/narrative device usage
  5. Vocabulary choice & range
  6. Cohesion & paragraphing
  7. Paragraph structure
  8. Sentence structure & clause variety
  9. Punctuation accuracy
  10. Spelling precision

---

#### C. Reading Comprehension
* **Text Genres:**
  * Informational & scientific articles, news reports, diagrams, biographical texts.
  * Narrative fiction excerpts, classic fables, poetry, short plays.
  * Advertisements, posters, instructional guides, and persuasive opinion pieces.
* **Comprehension Skill Levels:**
  * **Literal Recall:** Locating explicitly stated facts, dates, names, or events directly in text.
  * **Inferential Reasoning:** "Reading between the lines" to determine character motives, feelings, or implied outcomes.
  * **Author's Intent & Feature Analysis:** Identifying author purpose, vocabulary choice in context, visual layout elements, and text formatting effects.

---

#### D. Numeracy (Full Syllabus)
* **Number & Algebra:**
  * **Place Value & Large Numbers:** Reading, writing, comparing, and ordering numbers beyond 100,000.
  * **Four Operations:** Multi-digit addition/subtraction with regrouping, multiplication facts up to 12 x 12, multi-digit multiplication, and short division with/without remainders.
  * **Fractions & Decimals:** Fractions with related denominators (1/2, 1/4, 3/4, 1/5), number line placement, decimal place value (tenths, hundredths, thousandths), and fraction/decimal/percentage equivalencies.
  * **Factors, Multiples & Divisibility:** Identifying factors, multiples, prime/composite concepts, and divisibility rules.
  * **Patterns & Algebra:** Identifying/extending number sequences and solving for unknown values in number sentences.
  * **Financial Mathematics:** Word problems involving money, calculating total costs and change, and simple budgets.
* **Measurement & Space:**
  * **Units of Measurement:** Metric conversions (mm, cm, m, km; g, kg; mL, L), 12-hour/24-hour time conversions, timetables, and elapsed time.
  * **Perimeter, Area & Volume:** Perimeter and area of regular/irregular shapes, and volume/capacity comparisons using cubic grid units.
  * **Angles:** Estimating, measuring, and classifying angles (acute, right, obtuse, straight, reflex).
  * **2D Shapes & 3D Objects:** Properties of 2D shapes and 3D solids (prisms, pyramids, cylinders), connecting 3D objects to 2D nets.
  * **Location & Transformations:** Translations (slides), reflections (flips), rotations (turns), line/rotational symmetry, and grid coordinates/mapping (compass points, alpha-numeric grid references).
* **Statistics & Probability:**
  * **Data Interpretation & Representation:** Reading and interpreting column graphs, line graphs, dot plots, tables, and pie graphs; scaled axes interpretation; identifying trends, modes, and ranges.
  * **Probability & Chance:** Language of chance (impossible, unlikely, equal chance, likely, certain), expressing probability as simple fractions, and predicting outcomes of chance experiments.

---

### 4. Core Product Features
* **NAPLAN-Accurate Question Engine:** Drag-and-drop, multi-select grids, inline error spotter, split-screen reading view, and writing canvas.
* **Gamified Learning Modes:** Adventure Quest map, Daily 10-Minute Workout, Speed Challenge (fluency games), and Timed Test Simulator.
* **Parent Diagnostic Dashboard:** Maps results directly to official NAPLAN proficiency standards (Exceeding, Strong, Developing, Needs Additional Support), highlights weak points, and generates printable PDF worksheets.

---

### 5. Technical Architecture & Hybrid Pipeline
* **Core Engine:** Flutter or Godot 4.x (iOS, Android, Web).
* **90% Pre-Generated Data (Firebase Firestore):** Validated question banks, passages, and math schemas stored in JSON.
* **10% On-The-Fly AI (Firebase Cloud Functions + LLM):** Writing Studio evaluation against the 10-criteria rubric and dynamic step-by-step hint generation.

---

### 6. Development Roadmap
* **Phase 1 (Core MVP):** Question Engine UI, Numeracy & Conventions Banks, Adventure Map, Local Caching.
* **Phase 2 (Reading & Test Sim):** Split-Screen Reader, Timed NAPLAN Test Simulator, Adaptive Difficulty.
* **Phase 3 (Writing & Analytics):** Writing Studio with LLM Essay Evaluator, Parent Diagnostic Dashboard, Cloud Sync.
