import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:ace_naplan5/infrastructure/persistence/content_import_plan.dart';
import 'package:ace_naplan5/infrastructure/persistence/sqlite_content_importer.dart';
import 'package:ace_naplan5/infrastructure/persistence/sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

BankIdentity bank(int sequence, String digest) => BankIdentity(
    bankSequence: sequence,
    version: 'synthetic-v$sequence',
    schemaVersion: 1,
    digest: digest);

QuestionRevision question(String id, int bankSequence,
        {int revision = 1, String digest = 'item-digest'}) =>
    QuestionRevision(
      itemId: id,
      variantId: 'variant-$id',
      familyId: 'family',
      revision: revision,
      contentSchemaVersion: 1,
      bankVersion: 'synthetic-v$bankSequence',
      topic: 'synthetic-topic',
      domain: QuestionDomain.numeracy,
      difficulty: QuestionDifficulty.introductory,
      curriculumReferences: const ['synthetic-reference'],
      skillReferences: const ['synthetic-skill'],
      provenance: 'synthetic',
      license: 'synthetic',
      contentDigest: digest,
      reviewRecordId: 'synthetic-review',
      prompt: 'Synthetic prompt',
      stimulusDescription: 'Synthetic description',
      hint: 'Synthetic hint',
      explanation: 'Synthetic explanation',
      assets: const [],
      answerRule: SingleChoiceRule(
        options: [
          ChoiceOption(id: 'a', label: 'A'),
          ChoiceOption(id: 'b', label: 'B'),
        ],
        correctOptionId: 'a',
        scoringPolicyVersion: 1,
      ),
    );

Future<int> count(Database db, String table) async =>
    Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ??
    -1;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android import is atomic, idempotent and retryable after reopen',
      (tester) async {
    final path = p.join(await getDatabasesPath(),
        'sqlite_import_${DateTime.now().microsecondsSinceEpoch}.db');
    Database? db;
    final stamp = DateTime.utc(2026, 1, 1);
    try {
      db = await openPilotSqliteDatabase(path: path);
      final first = question('one', 1);
      expect(
          await importPrevalidatedContent(
              database: db,
              bank: bank(1, 'manifest-1'),
              questions: [first],
              importedAt: stamp),
          isTrue);
      expect(await count(db, 'content_manifest'), 1);
      expect(await count(db, 'question_revision'), 1);
      expect(await count(db, 'bank_item'), 1);
      expect(
          await importPrevalidatedContent(
              database: db,
              bank: bank(1, 'manifest-1'),
              questions: [first],
              importedAt: stamp),
          isFalse);
      expect(await count(db, 'content_manifest'), 1);
      await expectLater(
          importPrevalidatedContent(
              database: db,
              bank: bank(1, 'changed-digest'),
              questions: [first],
              importedAt: stamp),
          throwsA(isA<ContentImportConflict>().having((error) => error.reason,
              'reason', ContentImportConflictReason.bankDigestChanged)));
      expect(await count(db, 'content_manifest'), 1);
      expect(await count(db, 'question_revision'), 1);
      expect(await count(db, 'bank_item'), 1);

      final second = question('two', 2);
      Future<bool> update({Future<void> Function()? failure}) =>
          importPrevalidatedContent(
              database: db!,
              bank: bank(2, 'manifest-2'),
              questions: [question('one', 2), second],
              importedAt: stamp,
              beforeActivation: failure);
      await expectLater(
          update(failure: () async => throw StateError('injected failure')),
          throwsStateError);
      expect(await count(db, 'content_manifest'), 1);
      expect(await count(db, 'question_revision'), 1);
      expect(await count(db, 'bank_item'), 1);
      expect(
          (await db.query('content_manifest', where: 'active = 1'))
              .single['bank_version'],
          'synthetic-v1');
      await db.close();
      db = await openPilotSqliteDatabase(path: path);
      expect(await update(), isTrue);
      expect(await count(db, 'content_manifest'), 2);
      expect(await count(db, 'question_revision'), 2);
      expect(await count(db, 'bank_item'), 3);
      expect(
          (await db.query('content_manifest', where: 'active = 1'))
              .single['bank_version'],
          'synthetic-v2');
      expect(await update(), isFalse);
      expect(await count(db, 'content_manifest'), 2);
      expect(await count(db, 'question_revision'), 2);
      expect(await count(db, 'bank_item'), 3);
    } finally {
      await db?.close();
      await deleteDatabase(path);
    }
  });

  testWidgets('Android bank update preserves pinned history and rolls back',
      (tester) async {
    final path = p.join(await getDatabasesPath(),
        'sqlite_history_${DateTime.now().microsecondsSinceEpoch}.db');
    final stamp = DateTime.utc(2026, 1, 1).toIso8601String();
    final oldBank = bank(1, 'manifest-a');
    final newBank = bank(2, 'manifest-b');
    final oldChanged = question('changed', 1, digest: 'changed-r1');
    final retired = question('retired', 1, digest: 'retired-r1');
    final changed = question('changed', 2, revision: 2, digest: 'changed-r2');
    final added = question('added', 2, digest: 'added-r1');
    Database? db;
    late final List<Map<String, Object?>> originalAttempts;
    late final List<Map<String, Object?>> originalSessions;

    Future<void> expectLearnerRowsUnchanged() async {
      final database = db!;
      expect(await database.query('attempt', orderBy: 'attempt_id'),
          originalAttempts);
      expect(await database.query('practice_session', orderBy: 'session_id'),
          originalSessions);
    }

    Future<List<Map<String, Object?>>> activeItems() => db!.rawQuery('''
      SELECT bi.item_id, bi.revision
      FROM bank_item bi
      JOIN content_manifest cm ON cm.bank_version = bi.bank_version
      WHERE cm.active = 1
      ORDER BY bi.item_id
    ''');

    Future<void> expectOldState() async {
      final database = db!;
      await expectLearnerRowsUnchanged();
      expect(await activeItems(), [
        {'item_id': 'changed', 'revision': 1},
        {'item_id': 'retired', 'revision': 1},
      ]);
      expect(await count(database, 'content_manifest'), 1);
      expect(await count(database, 'question_revision'), 2);
      expect(await count(database, 'bank_item'), 2);
      expect((await database.query('attempt')).single['revision'], 1);
      expect(
          (await database.query('session_item',
                  where: 'session_id = ?', whereArgs: ['active-session']))
              .map((row) => '${row['item_id']}:${row['revision']}')
              .toSet(),
          {'changed:1', 'retired:1'});
    }

    Future<void> expectUpdatedState() async {
      final database = db!;
      await expectLearnerRowsUnchanged();
      expect(await activeItems(), [
        {'item_id': 'added', 'revision': 1},
        {'item_id': 'changed', 'revision': 2},
      ]);
      expect(await count(database, 'content_manifest'), 2);
      expect(await count(database, 'question_revision'), 4);
      expect(await count(database, 'bank_item'), 4);
      expect(
          (await database.query('question_revision',
                  where: 'item_id = ?', whereArgs: ['retired']))
              .single['revision'],
          1);
      expect((await database.query('attempt')).single['revision'], 1);
      expect(
          (await database.query('session_item',
                  where: 'session_id = ?', whereArgs: ['active-session']))
              .map((row) => '${row['item_id']}:${row['revision']}')
              .toSet(),
          {'changed:1', 'retired:1'});
      expect(await database.rawQuery('''
        SELECT a.attempt_id, q.content_digest
        FROM attempt a JOIN question_revision q
          ON q.item_id = a.item_id AND q.revision = a.revision
      '''), [
        {'attempt_id': 'historical-attempt', 'content_digest': 'changed-r1'}
      ]);
    }

    Future<bool> update({Future<void> Function()? failure}) =>
        importPrevalidatedContent(
            database: db!,
            bank: newBank,
            questions: [changed, added],
            importedAt: DateTime.utc(2026, 1, 2),
            beforeActivation: failure);

    try {
      db = await openPilotSqliteDatabase(path: path);
      expect(
          await importPrevalidatedContent(
              database: db,
              bank: oldBank,
              questions: [oldChanged, retired],
              importedAt: DateTime.utc(2026, 1, 1)),
          isTrue);
      await db.insert('practice_session', {
        'session_id': 'completed-session',
        'learner_key': 'local',
        'mode': 'fresh',
        'requested_size': 1,
        'actual_size': 1,
        'selection_policy_version': 1,
        'selection_seed': 1,
        'status': 'completed',
        'created_at': stamp,
        'completed_at': stamp,
      });
      await db.insert('session_item', {
        'session_id': 'completed-session',
        'ordinal': 0,
        'item_id': 'changed',
        'revision': 1,
        'presented': 1,
        'status': 'answered',
      });
      await db.insert('attempt', {
        'attempt_id': 'historical-attempt',
        'submission_key': 'historical-submit',
        'session_id': 'completed-session',
        'ordinal': 0,
        'attempt_number': 1,
        'item_id': 'changed',
        'revision': 1,
        'scoring_policy_version': 1,
        'normalized_response': 'a',
        'correct': 1,
        'independent': 1,
        'helped': 0,
        'review': 0,
        'submitted_at': stamp,
      });
      await db.insert('practice_session', {
        'session_id': 'active-session',
        'learner_key': 'local',
        'mode': 'fresh',
        'requested_size': 2,
        'actual_size': 2,
        'selection_policy_version': 1,
        'selection_seed': 2,
        'status': 'active',
        'created_at': stamp,
      });
      for (final (ordinal, itemId) in [(0, 'changed'), (1, 'retired')]) {
        await db.insert('session_item', {
          'session_id': 'active-session',
          'ordinal': ordinal,
          'item_id': itemId,
          'revision': 1,
        });
      }
      // Compare every persisted learner column, including response, submission
      // identity, scoring flags, session status, sizes, and timestamps.
      originalAttempts = await db.query('attempt', orderBy: 'attempt_id');
      originalSessions =
          await db.query('practice_session', orderBy: 'session_id');
      await expectOldState();

      await expectLater(
          update(failure: () async => throw StateError('injected failure')),
          throwsStateError);
      await expectOldState();
      await db.close();
      db = await openPilotSqliteDatabase(path: path);
      await expectOldState();

      expect(await update(), isTrue);
      await expectUpdatedState();
      expect(await update(), isFalse);
      await expectUpdatedState();
      await expectLater(
          importPrevalidatedContent(
              database: db,
              bank: oldBank,
              questions: [oldChanged, retired],
              importedAt: DateTime.utc(2026, 1, 1)),
          throwsA(isA<ContentImportConflict>().having((error) => error.reason,
              'reason', ContentImportConflictReason.bankDowngrade)));
      await expectUpdatedState();
      await db.close();
      db = await openPilotSqliteDatabase(path: path);
      await expectUpdatedState();
    } finally {
      await db?.close();
      await deleteDatabase(path);
    }
  });
}
