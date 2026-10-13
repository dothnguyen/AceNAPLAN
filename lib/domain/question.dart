import 'answer_rule.dart';

enum QuestionDomain { numeracy, conventions }

enum QuestionDifficulty { introductory, developing }

/// A content record is metadata, not proof of educator approval.
final class QuestionRevision {
  QuestionRevision({
    required this.itemId,
    required this.variantId,
    required this.familyId,
    required this.revision,
    required this.contentSchemaVersion,
    required this.bankVersion,
    required this.topic,
    required this.domain,
    required this.difficulty,
    required List<String> curriculumReferences,
    required List<String> skillReferences,
    required this.provenance,
    required this.license,
    required this.contentDigest,
    required this.reviewRecordId,
    required this.prompt,
    required this.stimulusDescription,
    required this.hint,
    required this.explanation,
    required List<QuestionAsset> assets,
    required this.answerRule,
  })  : curriculumReferences = List.unmodifiable(curriculumReferences),
        skillReferences = List.unmodifiable(skillReferences),
        assets = List.unmodifiable(assets) {
    for (final value in [
      itemId,
      variantId,
      familyId,
      bankVersion,
      topic,
      provenance,
      license,
      contentDigest,
      reviewRecordId,
      prompt,
      stimulusDescription,
      hint,
      explanation,
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError('Question metadata is required.');
      }
    }
    if (revision < 1 || contentSchemaVersion < 1) {
      throw ArgumentError('Question versions must be positive.');
    }
    if (this.curriculumReferences.isEmpty || this.skillReferences.isEmpty) {
      throw ArgumentError('Curriculum and skill references are required.');
    }
    if (this.curriculumReferences.any((value) => value.trim().isEmpty) ||
        this.skillReferences.any((value) => value.trim().isEmpty)) {
      throw ArgumentError('References must be nonblank.');
    }
    if (this.curriculumReferences.toSet().length !=
            this.curriculumReferences.length ||
        this.skillReferences.toSet().length != this.skillReferences.length) {
      throw ArgumentError('References must be unique.');
    }
    if (this.assets.map((asset) => asset.id).toSet().length !=
        this.assets.length) {
      throw ArgumentError('Asset IDs must be unique.');
    }
  }

  final String itemId;
  final String variantId;
  final String familyId;
  final int revision;
  final int contentSchemaVersion;
  final String bankVersion;
  final String topic;
  final QuestionDomain domain;
  final QuestionDifficulty difficulty;
  final List<String> curriculumReferences;
  final List<String> skillReferences;
  final String provenance;
  final String license;
  final String contentDigest;
  final String reviewRecordId;
  final String prompt;
  final String stimulusDescription;
  final String hint;
  final String explanation;
  final List<QuestionAsset> assets;
  final AnswerRule answerRule;
}

final class QuestionAsset {
  QuestionAsset(
      {required this.id, required this.digest, required this.description}) {
    if (id.trim().isEmpty ||
        digest.trim().isEmpty ||
        description.trim().isEmpty) {
      throw ArgumentError('Asset ID, digest and description are required.');
    }
  }

  final String id;
  final String digest;
  final String description;
}
