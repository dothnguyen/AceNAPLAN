import '../../domain/question.dart';

/// Identity read from an already validated bundled manifest or active database.
final class BankIdentity {
  BankIdentity({
    required this.bankSequence,
    required this.version,
    required this.schemaVersion,
    required this.digest,
  }) {
    if (bankSequence < 1 ||
        version.trim().isEmpty ||
        digest.trim().isEmpty ||
        schemaVersion < 1) {
      throw const ContentImportConflict(
          ContentImportConflictReason.invalidMetadata);
    }
  }

  final int bankSequence;
  final String version;
  final int schemaVersion;
  final String digest;
}

/// The immutable key and digest already stored for a question revision.
final class StoredRevisionDigest {
  StoredRevisionDigest({
    required this.itemId,
    required this.revision,
    required this.digest,
  }) {
    if (itemId.trim().isEmpty || digest.trim().isEmpty || revision < 1) {
      throw const ContentImportConflict(
          ContentImportConflictReason.invalidMetadata);
    }
  }

  final String itemId;
  final int revision;
  final String digest;
}

/// A selected item revision in the new bank; order follows the input manifest.
final class BankMembership {
  const BankMembership(this.itemId, this.revision);

  final String itemId;
  final int revision;
}

enum ContentImportConflictReason {
  invalidMetadata,
  unsupportedSchema,
  duplicateMembership,
  duplicateRevision,
  bankDigestChanged,
  revisionDigestChanged,
  incompleteActiveBank,
  bankDowngrade,
  bankSequenceConflict,
}

/// A typed, content-free failure suitable for a safe caller-facing error.
final class ContentImportConflict implements Exception {
  const ContentImportConflict(this.reason);

  final ContentImportConflictReason reason;

  @override
  String toString() => 'Content import conflict: ${reason.name}';
}

/// A read-only instruction for the later Android transaction implementation.
///
/// For [isNoOp], all collections are empty and [manifestToActivate] is null.
/// Otherwise the caller inserts [missingRevisions], writes [membership], then
/// switches [manifestToActivate] last, in one transaction. Historical revisions
/// are never deleted by this plan. The planner does not validate raw content,
/// assets, answer keys or educator review, compute digests, migrate SQLite, or
/// recover interrupted writes; those remain prerequisites for the parent task.
final class ContentImportPlan {
  ContentImportPlan._({
    required this.isNoOp,
    required List<QuestionRevision> missingRevisions,
    required List<BankMembership> membership,
    required this.manifestToActivate,
  })  : missingRevisions = List.unmodifiable(missingRevisions),
        membership = List.unmodifiable(membership);

  final bool isNoOp;
  final List<QuestionRevision> missingRevisions;
  final List<BankMembership> membership;
  final BankIdentity? manifestToActivate;
}

/// Plans an import from *prevalidated* content records and stored metadata.
///
/// The caller must validate the complete bundle, including assets and approval
/// evidence, before invoking this pure function. It must read the active bank and
/// active membership and stored revision digests in the same transaction used
/// to apply the result.
/// [supportedSchemaVersion] is the one content schema this caller understands.
/// No database writes or mutation of supplied collections occur here.
ContentImportPlan planContentImport({
  required BankIdentity incomingBank,
  required List<QuestionRevision> incomingRevisions,
  required BankIdentity? activeBank,
  required List<BankMembership> activeMembership,
  required List<StoredRevisionDigest> storedRevisions,
  required int supportedSchemaVersion,
}) {
  if (supportedSchemaVersion < 1 ||
      incomingBank.schemaVersion != supportedSchemaVersion ||
      (activeBank != null &&
          activeBank.schemaVersion != supportedSchemaVersion)) {
    throw const ContentImportConflict(
        ContentImportConflictReason.unsupportedSchema);
  }
  if (incomingRevisions.isEmpty) {
    throw const ContentImportConflict(
        ContentImportConflictReason.invalidMetadata);
  }

  final stored = <(String, int), String>{};
  for (final revision in storedRevisions) {
    final key = (revision.itemId, revision.revision);
    if (stored.containsKey(key)) {
      throw const ContentImportConflict(
          ContentImportConflictReason.duplicateRevision);
    }
    stored[key] = revision.digest;
  }

  if (activeBank == null && activeMembership.isNotEmpty) {
    throw const ContentImportConflict(
        ContentImportConflictReason.invalidMetadata);
  }
  final activeIds = <String>{};
  final activeKeys = <(String, int)>{};
  for (final entry in activeMembership) {
    if (entry.itemId.trim().isEmpty || entry.revision < 1) {
      throw const ContentImportConflict(
          ContentImportConflictReason.invalidMetadata);
    }
    if (!activeIds.add(entry.itemId) ||
        !activeKeys.add((entry.itemId, entry.revision))) {
      throw const ContentImportConflict(
          ContentImportConflictReason.duplicateMembership);
    }
    if (!stored.containsKey((entry.itemId, entry.revision))) {
      throw const ContentImportConflict(
          ContentImportConflictReason.incompleteActiveBank);
    }
  }
  if (activeBank != null) {
    if (incomingBank.bankSequence < activeBank.bankSequence) {
      throw const ContentImportConflict(
          ContentImportConflictReason.bankDowngrade);
    }
    if (incomingBank.bankSequence == activeBank.bankSequence &&
        incomingBank.version != activeBank.version) {
      throw const ContentImportConflict(
          ContentImportConflictReason.bankSequenceConflict);
    }
    if (incomingBank.version == activeBank.version &&
        incomingBank.bankSequence != activeBank.bankSequence) {
      throw const ContentImportConflict(
          ContentImportConflictReason.bankSequenceConflict);
    }
  }

  final membershipIds = <String>{};
  final revisionKeys = <(String, int)>{};
  final membership = <BankMembership>[];
  final missing = <QuestionRevision>[];
  for (final question in incomingRevisions) {
    if (question.itemId.trim().isEmpty ||
        question.contentDigest.trim().isEmpty ||
        question.bankVersion != incomingBank.version ||
        question.contentSchemaVersion != incomingBank.schemaVersion) {
      throw const ContentImportConflict(
          ContentImportConflictReason.invalidMetadata);
    }
    if (!membershipIds.add(question.itemId)) {
      throw const ContentImportConflict(
          ContentImportConflictReason.duplicateMembership);
    }
    final key = (question.itemId, question.revision);
    if (!revisionKeys.add(key)) {
      throw const ContentImportConflict(
          ContentImportConflictReason.duplicateRevision);
    }
    final existingDigest = stored[key];
    if (existingDigest != null && existingDigest != question.contentDigest) {
      throw const ContentImportConflict(
        ContentImportConflictReason.revisionDigestChanged,
      );
    }
    if (existingDigest == null) {
      missing.add(question);
    }
    membership.add(BankMembership(question.itemId, question.revision));
  }

  if (activeBank?.version == incomingBank.version) {
    if (activeBank!.digest != incomingBank.digest) {
      throw const ContentImportConflict(
        ContentImportConflictReason.bankDigestChanged,
      );
    }
    if (missing.isNotEmpty ||
        activeKeys.length != membership.length ||
        !activeKeys.containsAll(
            membership.map((entry) => (entry.itemId, entry.revision)))) {
      throw const ContentImportConflict(
        ContentImportConflictReason.incompleteActiveBank,
      );
    }
    return ContentImportPlan._(
      isNoOp: true,
      missingRevisions: const [],
      membership: const [],
      manifestToActivate: null,
    );
  }
  return ContentImportPlan._(
    isNoOp: false,
    missingRevisions: missing,
    membership: membership,
    manifestToActivate: incomingBank,
  );
}
