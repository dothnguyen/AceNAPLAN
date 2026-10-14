import 'package:sqflite/sqflite.dart';

/// Android pilot schema only. Content import, upgrades and restart recovery are
/// separate work; no learner data is written when this schema is created.
const int sqliteSchemaVersion = 1;

/// Called by sqflite's transactional onCreate callback. Never use REPLACE for
/// content or history rows: revisions and attempts are immutable records.
Future<void> createSqliteSchemaV1(Database db) async {
  for (final statement in _schemaV1) {
    await db.execute(statement);
  }
}

const _schemaV1 = <String>[
  '''CREATE TABLE content_manifest (
    bank_version TEXT PRIMARY KEY NOT NULL CHECK (length(bank_version) > 0),
    bank_sequence INTEGER NOT NULL UNIQUE CHECK (bank_sequence > 0),
    schema_version INTEGER NOT NULL CHECK (schema_version > 0),
    manifest_digest TEXT NOT NULL CHECK (length(manifest_digest) > 0),
    imported_at TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1))
  )''',
  '''CREATE UNIQUE INDEX one_active_content_manifest
    ON content_manifest(active) WHERE active = 1''',
  '''CREATE TABLE question_revision (
    item_id TEXT NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    variant_id TEXT NOT NULL,
    family_id TEXT NOT NULL,
    topic TEXT NOT NULL,
    domain TEXT NOT NULL CHECK (domain IN ('numeracy', 'conventions')),
    difficulty TEXT NOT NULL CHECK (difficulty IN ('introductory', 'developing')),
    content_schema_version INTEGER NOT NULL CHECK (content_schema_version > 0),
    curriculum_references_json TEXT NOT NULL,
    skill_references_json TEXT NOT NULL,
    provenance TEXT NOT NULL,
    license TEXT NOT NULL,
    prompt TEXT NOT NULL,
    stimulus_description TEXT NOT NULL,
    answer_rule_json TEXT NOT NULL,
    hint TEXT NOT NULL,
    explanation TEXT NOT NULL,
    assets_json TEXT NOT NULL,
    content_digest TEXT NOT NULL,
    review_record_id TEXT NOT NULL,
    PRIMARY KEY (item_id, revision)
  )''',
  '''CREATE TABLE bank_item (
    bank_version TEXT NOT NULL,
    item_id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    PRIMARY KEY (bank_version, item_id),
    FOREIGN KEY (bank_version) REFERENCES content_manifest(bank_version),
    FOREIGN KEY (item_id, revision) REFERENCES question_revision(item_id, revision)
  )''',
  '''CREATE TABLE practice_session (
    session_id TEXT PRIMARY KEY NOT NULL,
    learner_key TEXT NOT NULL CHECK (length(learner_key) > 0),
    mode TEXT NOT NULL CHECK (mode IN ('fresh', 'review')),
    requested_size INTEGER NOT NULL CHECK (requested_size > 0),
    actual_size INTEGER NOT NULL CHECK (actual_size >= 0 AND actual_size <= requested_size),
    selection_policy_version INTEGER NOT NULL CHECK (selection_policy_version > 0),
    selection_seed INTEGER NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active', 'paused', 'completed', 'abandoned')),
    created_at TEXT NOT NULL,
    completed_at TEXT,
    UNIQUE (session_id, learner_key)
  )''',
  '''CREATE UNIQUE INDEX one_open_practice_session
    ON practice_session(learner_key)
    WHERE status IN ('active', 'paused')''',
  '''CREATE TABLE session_item (
    session_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
    item_id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    presented INTEGER NOT NULL DEFAULT 0 CHECK (presented IN (0, 1)),
    helped INTEGER NOT NULL DEFAULT 0 CHECK (helped IN (0, 1)),
    status TEXT NOT NULL DEFAULT 'reserved'
      CHECK (status IN ('reserved', 'presented', 'answered', 'retired')),
    PRIMARY KEY (session_id, ordinal),
    UNIQUE (session_id, item_id),
    UNIQUE (session_id, ordinal, item_id, revision),
    FOREIGN KEY (session_id) REFERENCES practice_session(session_id),
    FOREIGN KEY (item_id, revision) REFERENCES question_revision(item_id, revision)
  )''',
  '''CREATE TABLE item_exposure (
    learner_key TEXT NOT NULL,
    item_id TEXT NOT NULL,
    first_presented_at TEXT NOT NULL,
    first_session_id TEXT NOT NULL,
    PRIMARY KEY (learner_key, item_id),
    FOREIGN KEY (first_session_id, item_id)
      REFERENCES session_item(session_id, item_id),
    FOREIGN KEY (first_session_id, learner_key)
      REFERENCES practice_session(session_id, learner_key)
  )''',
  '''CREATE TABLE attempt (
    attempt_id TEXT PRIMARY KEY NOT NULL,
    submission_key TEXT NOT NULL UNIQUE,
    session_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    attempt_number INTEGER NOT NULL CHECK (attempt_number > 0),
    item_id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    scoring_policy_version INTEGER NOT NULL CHECK (scoring_policy_version > 0),
    normalized_response TEXT NOT NULL CHECK (length(normalized_response) <= 1024),
    correct INTEGER NOT NULL CHECK (correct IN (0, 1)),
    independent INTEGER NOT NULL CHECK (independent IN (0, 1)),
    helped INTEGER NOT NULL CHECK (helped IN (0, 1)),
    review INTEGER NOT NULL CHECK (review IN (0, 1)),
    submitted_at TEXT NOT NULL,
    UNIQUE (session_id, ordinal, attempt_number),
    FOREIGN KEY (session_id, ordinal, item_id, revision)
      REFERENCES session_item(session_id, ordinal, item_id, revision)
  )''',
];
