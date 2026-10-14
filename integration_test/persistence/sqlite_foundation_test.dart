import 'package:ace_naplan5/infrastructure/persistence/sqlite_database.dart';
import 'package:ace_naplan5/infrastructure/persistence/sqlite_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android isolated schema, constraints, rollback and reopen',
      (tester) async {
    final path = p.join(await getDatabasesPath(),
        'sqlite_foundation_${DateTime.now().microsecondsSinceEpoch}.db');
    Database? db;
    try {
      db = await openPilotSqliteDatabase(path: path);
      expect(await db.getVersion(), sqliteSchemaVersion);
      expect(
          (await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
      final tables = (await db.rawQuery('''SELECT name FROM sqlite_master
          WHERE type = 'table' AND name NOT LIKE 'sqlite_%' '''))
          .map((row) => row['name'])
          .toSet();
      expect(
          tables,
          containsAll(<String>{
            'content_manifest',
            'question_revision',
            'bank_item',
            'practice_session',
            'session_item',
            'item_exposure',
            'attempt'
          }));

      await db.insert('content_manifest', {
        'bank_version': 'synthetic-v1',
        'bank_sequence': 1,
        'schema_version': 1,
        'manifest_digest': 'synthetic-digest',
        'imported_at': '2026-01-01T00:00:00Z',
        'active': 1,
      });
      await db.insert('question_revision', {
        'item_id': 'item-1',
        'revision': 1,
        'variant_id': 'variant-1',
        'family_id': 'family-1',
        'topic': 'topic',
        'domain': 'numeracy',
        'difficulty': 'introductory',
        'content_schema_version': 1,
        'curriculum_references_json': '["ref"]',
        'skill_references_json': '["skill"]',
        'provenance': 'synthetic',
        'license': 'synthetic',
        'prompt': 'Synthetic prompt',
        'stimulus_description': 'Synthetic description',
        'answer_rule_json': '{}',
        'hint': 'Synthetic hint',
        'explanation': 'Synthetic explanation',
        'assets_json': '[]',
        'content_digest': 'synthetic-item-digest',
        'review_record_id': 'synthetic-review',
      });
      await db.insert('bank_item', {
        'bank_version': 'synthetic-v1',
        'item_id': 'item-1',
        'revision': 1,
      });
      await expectLater(
        db.insert('bank_item', {
          'bank_version': 'synthetic-v1',
          'item_id': 'missing',
          'revision': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.insert('content_manifest', {
          'bank_version': 'synthetic-v2',
          'bank_sequence': 2,
          'schema_version': 1,
          'manifest_digest': 'synthetic-digest-2',
          'imported_at': '2026-01-02T00:00:00Z',
          'active': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('practice_session', {
        'session_id': 'session-1',
        'learner_key': 'local-learner',
        'mode': 'fresh',
        'requested_size': 1,
        'actual_size': 1,
        'selection_policy_version': 1,
        'selection_seed': 1,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      await db.insert('session_item', {
        'session_id': 'session-1',
        'ordinal': 0,
        'item_id': 'item-1',
        'revision': 1,
      });
      await expectLater(
        db.insert('session_item', {
          'session_id': 'session-1',
          'ordinal': 1,
          'item_id': 'item-1',
          'revision': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('attempt', {
        'attempt_id': 'attempt-1',
        'submission_key': 'submit-1',
        'session_id': 'session-1',
        'ordinal': 0,
        'attempt_number': 1,
        'item_id': 'item-1',
        'revision': 1,
        'scoring_policy_version': 1,
        'normalized_response': 'a',
        'correct': 1,
        'independent': 1,
        'helped': 0,
        'review': 0,
        'submitted_at': '2026-01-01T00:01:00Z',
      });
      await expectLater(
        db.insert('attempt', {
          'attempt_id': 'attempt-2',
          'submission_key': 'submit-1',
          'session_id': 'session-1',
          'ordinal': 0,
          'attempt_number': 2,
          'item_id': 'item-1',
          'revision': 1,
          'scoring_policy_version': 1,
          'normalized_response': 'b',
          'correct': 0,
          'independent': 0,
          'helped': 0,
          'review': 1,
          'submitted_at': '2026-01-01T00:02:00Z',
        }),
        throwsA(isA<DatabaseException>()),
      );
      for (final invalidExposure in [
        {'learner_key': 'local-learner', 'item_id': 'unreserved-item'},
        {'learner_key': 'different-learner', 'item_id': 'item-1'},
      ]) {
        await expectLater(
          db.insert('item_exposure', {
            ...invalidExposure,
            'first_presented_at': '2026-01-01T00:00:00Z',
            'first_session_id': 'session-1',
          }),
          throwsA(isA<DatabaseException>()),
        );
      }
      await expectLater(db.transaction((txn) async {
        await txn.insert('item_exposure', {
          'learner_key': 'local-learner',
          'item_id': 'item-1',
          'first_presented_at': '2026-01-01T00:00:00Z',
          'first_session_id': 'session-1',
        });
        throw StateError('synthetic rollback');
      }), throwsStateError);
      expect(
          Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM item_exposure')),
          0);

      await db.close();
      db = await openPilotSqliteDatabase(path: path);
      expect(
          Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM attempt')),
          1);
      await db.setVersion(sqliteSchemaVersion + 1);
      await db.close();
      db = null;
      await expectLater(
        openPilotSqliteDatabase(path: path),
        throwsA(isA<UnsupportedSqliteSchema>().having(
          (error) => error.foundVersion,
          'foundVersion',
          sqliteSchemaVersion + 1,
        )),
      );
      db = await openDatabase(path, version: sqliteSchemaVersion + 1);
      expect(await db.getVersion(), sqliteSchemaVersion + 1);
      expect(
          Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM attempt')),
          1);
    } finally {
      await db?.close();
      await deleteDatabase(path); // Only this uniquely named synthetic test DB.
    }
  });
}
