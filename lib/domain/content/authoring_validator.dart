import '../answer_rule.dart';
import '../question.dart';

/// A structural authoring check. An empty result is never educator approval.
/// The catalogue may be draft planning data; release approval is a separate gate.
List<String> validateAuthoredItems({
  required List<QuestionRevision> items,
  required Map<String, dynamic> catalogue,
}) {
  final issues = <String>[];
  if (catalogue['schema_version'] != 1 || catalogue['families'] is! List) {
    return ['Malformed family catalogue or unsupported schema version'];
  }

  final families = <String, Map<String, dynamic>>{};
  for (final raw in catalogue['families'] as List) {
    if (raw is! Map<String, dynamic> || raw['id'] is! String) {
      issues.add('Malformed family catalogue entry');
      continue;
    }
    final id = raw['id'] as String;
    if (families.containsKey(id)) issues.add('Duplicate catalogue family $id');
    families[id] = raw;
  }

  final revisions = <String>{};
  final identity =
      <String, (String, String, QuestionDomain, String, QuestionDifficulty)>{};
  for (final item in items) {
    final label = '${item.itemId}@${item.revision}';
    if (!revisions.add(label)) issues.add('Duplicate item revision $label');
    final stable = (
      item.familyId,
      item.variantId,
      item.domain,
      item.topic,
      item.difficulty
    );
    final prior = identity[item.itemId];
    if (prior != null && prior != stable) {
      issues.add('Unstable item identity ${item.itemId}');
    }
    identity[item.itemId] = stable;
    final family = families[item.familyId];
    if (family == null) {
      issues.add('Unknown family for $label');
      continue;
    }
    if (family['domain'] != item.domain.name || family['topic'] != item.topic) {
      issues.add('Family domain or topic mismatch for $label');
    }
    if (item.contentSchemaVersion != catalogue['schema_version']) {
      issues.add('Unsupported content schema for $label');
    }
    final difficulties = family['difficulty_targets'];
    if (difficulties is! Map ||
        difficulties[item.difficulty.name] is! int ||
        (difficulties[item.difficulty.name] as int) < 1) {
      issues.add('Unsupported difficulty for $label');
    }
    if (family['skill'] is! String ||
        !item.skillReferences.contains(family['skill'])) {
      issues.add('Missing catalogue skill for $label');
    }
    final variants = family['variants'];
    Map? variant;
    if (variants is List) {
      for (final raw in variants) {
        if (raw is Map && raw['id'] == item.variantId) variant = raw;
      }
    }
    if (variant == null) {
      issues.add('Unknown family variant for $label');
      continue;
    }
    final format = variant['response_format'] ?? family['response_format'];
    final rule = item.answerRule;
    final matches = switch (format) {
      'single_choice' => rule is SingleChoiceRule,
      'sentence_choice' => rule is SentenceChoiceRule,
      'numeric' => rule is NumericRule && rule.displayedUnit == null,
      'numeric_with_displayed_unit' =>
        rule is NumericRule && rule.displayedUnit != null,
      'spelling_entry' => rule is SpellingRule,
      _ => false,
    };
    if (!matches) issues.add('Response format mismatch for $label');
    if (rule.scoringPolicyVersion < 1) {
      issues.add('Invalid scoring policy for $label');
    }
    if (rule is SingleChoiceRule || rule is SentenceChoiceRule) {
      final options = rule is SingleChoiceRule
          ? rule.options
          : (rule as SentenceChoiceRule).options;
      final keys = options.map((option) => option.id).toSet();
      final correct = rule is SingleChoiceRule
          ? rule.correctOptionId
          : (rule as SentenceChoiceRule).correctOptionId;
      if (options.length < 2 ||
          keys.length != options.length ||
          !keys.contains(correct)) {
        issues.add('Invalid choice key for $label');
      }
      if (options.map((option) => option.label.trim()).toSet().length !=
          options.length) {
        issues.add('Ambiguous choice labels for $label');
      }
    } else if (rule is NumericRule &&
        ExactDecimal.parse(rule.correctValue.canonical) == null) {
      issues.add('Invalid numeric key for $label');
    } else if (rule is SpellingRule && rule.target.trim().isEmpty) {
      issues.add('Invalid spelling key for $label');
    }
    if (item.itemId.trim().isEmpty ||
        item.variantId.trim().isEmpty ||
        item.bankVersion.trim().isEmpty ||
        item.contentDigest.trim().isEmpty ||
        item.provenance.trim().isEmpty ||
        item.license.trim().isEmpty ||
        item.reviewRecordId.trim().isEmpty ||
        item.prompt.trim().isEmpty ||
        item.hint.trim().isEmpty ||
        item.explanation.trim().isEmpty ||
        item.curriculumReferences.isEmpty ||
        item.skillReferences.isEmpty ||
        item.revision < 1 ||
        item.contentSchemaVersion < 1) {
      issues.add('Missing required metadata for $label');
    }
  }
  return issues;
}
