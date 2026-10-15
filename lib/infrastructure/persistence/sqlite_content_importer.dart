import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/question.dart';
import 'content_bundle_codec.dart';
import 'content_import_plan.dart';

/// Imports records whose complete bundle, digests, assets, and review evidence
/// were validated before this call. This method does not grant content approval.
/// Session creation must be paused by the caller while an import runs.
/// Returns false only when the active bank already matches exactly.
Future<bool> importPrevalidatedContent({
  required Database database,
  required BankIdentity bank,
  required List<QuestionRevision> questions,
  required DateTime importedAt,
  Future<void> Function()? beforeActivation,
}) async {
  final codec = const ContentBundleCodec();
  return database.transaction((txn) async {
    final activeRows = await txn.query('content_manifest',
        columns: [
          'bank_version',
          'bank_sequence',
          'schema_version',
          'manifest_digest'
        ],
        where: 'active = ?',
        whereArgs: [1]);
    if (activeRows.length > 1) {
      throw const ContentImportConflict(
          ContentImportConflictReason.invalidMetadata);
    }
    final active = activeRows.isEmpty ? null : _bank(activeRows.single);
    final membershipRows = active == null
        ? <Map<String, Object?>>[]
        : await txn.query('bank_item',
            columns: ['item_id', 'revision'],
            where: 'bank_version = ?',
            whereArgs: [active.version]);
    final storedRows = await txn.query('question_revision',
        columns: ['item_id', 'revision', 'content_digest']);
    final plan = planContentImport(
      incomingBank: bank,
      incomingRevisions: questions,
      activeBank: active,
      activeMembership: [
        for (final row in membershipRows)
          BankMembership(row['item_id'] as String, row['revision'] as int)
      ],
      storedRevisions: [
        for (final row in storedRows)
          StoredRevisionDigest(
              itemId: row['item_id'] as String,
              revision: row['revision'] as int,
              digest: row['content_digest'] as String)
      ],
      supportedSchemaVersion: ContentBundleCodec.schemaVersion,
    );
    if (plan.isNoOp) return false;

    // Existing version/sequence collisions fail through SQLite constraints;
    // no conflict algorithm deletes or rewrites prior manifests or revisions.
    for (final question in plan.missingRevisions) {
      await txn.insert('question_revision', {
        'item_id': question.itemId,
        'revision': question.revision,
        'variant_id': question.variantId,
        'family_id': question.familyId,
        'topic': question.topic,
        'domain': question.domain.name,
        'difficulty': question.difficulty.name,
        'content_schema_version': question.contentSchemaVersion,
        'curriculum_references_json': jsonEncode(question.curriculumReferences),
        'skill_references_json': jsonEncode(question.skillReferences),
        'provenance': question.provenance,
        'license': question.license,
        'prompt': question.prompt,
        'stimulus_description': question.stimulusDescription,
        'answer_rule_json': codec.encodeAnswerRule(question.answerRule),
        'hint': question.hint,
        'explanation': question.explanation,
        'assets_json': codec.encodeAssets(question.assets),
        'content_digest': question.contentDigest,
        'review_record_id': question.reviewRecordId,
      });
    }
    final newBank = plan.manifestToActivate!;
    await txn.insert('content_manifest', {
      'bank_version': newBank.version,
      'bank_sequence': newBank.bankSequence,
      'schema_version': newBank.schemaVersion,
      'manifest_digest': newBank.digest,
      'imported_at': importedAt.toUtc().toIso8601String(),
      'active': 0,
    });
    for (final member in plan.membership) {
      await txn.insert('bank_item', {
        'bank_version': newBank.version,
        'item_id': member.itemId,
        'revision': member.revision,
      });
    }
    await beforeActivation?.call();
    if (active != null) {
      await txn.update('content_manifest', {'active': 0},
          where: 'bank_version = ?', whereArgs: [active.version]);
    }
    await txn.update('content_manifest', {'active': 1},
        where: 'bank_version = ?', whereArgs: [newBank.version]);
    return true;
  });
}

BankIdentity _bank(Map<String, Object?> row) => BankIdentity(
      bankSequence: row['bank_sequence'] as int,
      version: row['bank_version'] as String,
      schemaVersion: row['schema_version'] as int,
      digest: row['manifest_digest'] as String,
    );
