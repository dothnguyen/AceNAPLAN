import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:ace_naplan5/infrastructure/persistence/content_import_plan.dart';
import 'package:ace_naplan5/infrastructure/persistence/sqlite_content_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

final class _RecordingDatabase implements Database {
  _RecordingDatabase(this.rows);

  final Map<String, List<Map<String, Object?>>> rows;
  final writes = <String>[];

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
          {bool? exclusive}) =>
      action(_RecordingTransaction(rows, writes));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingTransaction implements Transaction {
  _RecordingTransaction(this.rows, this.writes);

  final Map<String, List<Map<String, Object?>>> rows;
  final List<String> writes;

  @override
  Future<List<Map<String, Object?>>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    return rows[table] ?? [];
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    writes.add('insert:$table');
    return 1;
  }

  @override
  Future<int> update(String table, Map<String, Object?> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) async {
    writes.add('activate:$table:${values['active']}');
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

QuestionRevision _question() => QuestionRevision(
      itemId: 'synthetic-item',
      variantId: 'synthetic-variant',
      familyId: 'synthetic-family',
      revision: 1,
      contentSchemaVersion: 1,
      bankVersion: 'synthetic-v1',
      topic: 'synthetic-topic',
      domain: QuestionDomain.numeracy,
      difficulty: QuestionDifficulty.introductory,
      curriculumReferences: const ['synthetic-ref'],
      skillReferences: const ['synthetic-skill'],
      provenance: 'synthetic',
      license: 'synthetic',
      contentDigest: 'synthetic-item-digest',
      reviewRecordId: 'synthetic-review',
      prompt: 'Synthetic prompt',
      stimulusDescription: 'Synthetic description',
      hint: 'Synthetic hint',
      explanation: 'Synthetic explanation',
      assets: const [],
      answerRule: SingleChoiceRule(options: [
        ChoiceOption(id: 'a', label: 'A'),
        ChoiceOption(id: 'b', label: 'B')
      ], correctOptionId: 'a', scoringPolicyVersion: 1),
    );

void main() {
  test('new import writes revisions and membership before activation',
      () async {
    final db = _RecordingDatabase({});
    final result = await importPrevalidatedContent(
        database: db,
        bank: BankIdentity(
            bankSequence: 1,
            version: 'synthetic-v1',
            schemaVersion: 1,
            digest: 'synthetic-bank-digest'),
        questions: [_question()],
        importedAt: DateTime.utc(2026));
    expect(result, isTrue);
    expect(db.writes, [
      'insert:question_revision',
      'insert:content_manifest',
      'insert:bank_item',
      'activate:content_manifest:1',
    ]);
  });

  test('identical active bank performs no writes', () async {
    final db = _RecordingDatabase({
      'content_manifest': [
        {
          'bank_version': 'synthetic-v1',
          'bank_sequence': 1,
          'schema_version': 1,
          'manifest_digest': 'synthetic-bank-digest',
        }
      ],
      'bank_item': [
        {'item_id': 'synthetic-item', 'revision': 1}
      ],
      'question_revision': [
        {
          'item_id': 'synthetic-item',
          'revision': 1,
          'content_digest': 'synthetic-item-digest'
        }
      ],
    });
    final result = await importPrevalidatedContent(
        database: db,
        bank: BankIdentity(
            bankSequence: 1,
            version: 'synthetic-v1',
            schemaVersion: 1,
            digest: 'synthetic-bank-digest'),
        questions: [_question()],
        importedAt: DateTime.utc(2026));
    expect(result, isFalse);
    expect(db.writes, isEmpty);
  });
}
