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
}
