import '../answer_rule.dart';
import '../question.dart';
import 'authoring_validator.dart';

/// Structural coverage only. Passing this check does not approve draft content
/// or establish that the questions differ meaningfully for learners.
List<String> validateBankQuotas({
  required List<QuestionRevision> items,
  required Map<String, dynamic> catalogue,
}) {
  final issues = <String>[];
  const selectedFamilies = {
    'N-PV-01',
    'N-PV-02',
    'N-OP-01',
    'N-OP-02',
    'N-FD-01',
    'N-FD-02',
    'N-PA-01',
    'N-PA-02',
    'N-MT-01',
    'N-MT-02',
    'N-SP-01',
    'N-SP-02',
    'N-DT-01',
    'N-DT-02',
    'N-CH-01',
    'N-CH-02',
    'C-SP-01',
    'C-SP-02',
    'C-GR-01',
    'C-GR-02',
    'C-PU-01',
    'C-PU-02',
  };
  final rawFamilies = catalogue['families'];
  if (catalogue['schema_version'] != 1 || rawFamilies is! List) {
    return ['Malformed family catalogue or unsupported schema version'];
  }
  final families = <String, Map<String, dynamic>>{};
  for (final raw in rawFamilies) {
    if (raw is! Map<String, dynamic> || raw['id'] is! String) {
      issues.add('Malformed family catalogue entry');
      continue;
    }
    final id = raw['id'] as String;
    if (families.containsKey(id)) issues.add('Duplicate catalogue family $id');
    families[id] = raw;
  }
  for (final id in selectedFamilies.difference(families.keys.toSet())) {
    issues.add('Missing selected family $id');
  }
  for (final id in families.keys.toSet().difference(selectedFamilies)) {
    issues.add('Extra catalogue family $id');
  }
  if (catalogue['planned_family_count'] != 22 ||
      catalogue['planned_item_count'] != 440) {
    issues.add('Catalogue bank target must be 22 families and 440 items');
  }

  issues.addAll(validateAuthoredItems(items: items, catalogue: catalogue));
  final ids = <String>{};
  final byFamily = <String, List<QuestionRevision>>{};
  final stimuli = <(String, String, String)>{};
  for (final item in items) {
    if (!ids.add(item.itemId)) {
      issues.add('Duplicate stable item ID ${item.itemId}');
    }
    byFamily.putIfAbsent(item.familyId, () => []).add(item);
    final signature = (
      item.prompt.trim(),
      item.stimulusDescription.trim(),
      _answerKey(item.answerRule),
    );
    if (!stimuli.add(signature)) {
      issues.add('Repeated stimulus and answer for ${item.itemId}');
    }
  }
  if (items.length != 440 || ids.length != 440) {
    issues.add('Bank requires 440 distinct stable item IDs');
  }
  for (final id in byFamily.keys.toSet().difference(selectedFamilies)) {
    issues.add('Extra bank family $id');
  }
  for (final id in selectedFamilies) {
    final family = families[id];
    final group = byFamily[id] ?? const <QuestionRevision>[];
    if (group.length != 20) issues.add('Family $id requires 20 items');
    if (group
                .where((item) =>
                    item.difficulty == QuestionDifficulty.introductory)
                .length !=
            10 ||
        group
                .where(
                    (item) => item.difficulty == QuestionDifficulty.developing)
                .length !=
            10) {
      issues.add('Family $id requires 10 introductory and 10 developing items');
    }
    if (family == null) continue;
    if (family['target_item_count'] != 20 ||
        family['difficulty_targets'] is! Map ||
        (family['difficulty_targets'] as Map)['introductory'] != 10 ||
        (family['difficulty_targets'] as Map)['developing'] != 10) {
      issues.add('Invalid catalogue quotas for $id');
    }
    final rawVariants = family['variants'];
    if (rawVariants is! List || rawVariants.isEmpty) {
      issues.add('Missing variant quotas for $id');
      continue;
    }
    final variants = <String, int>{};
    var declaredTotal = 0;
    for (final raw in rawVariants) {
      if (raw is! Map ||
          raw['id'] is! String ||
          raw['target_item_count'] is! int ||
          (raw['target_item_count'] as int) < 1) {
        issues.add('Invalid variant quota for $id');
        continue;
      }
      final variantId = raw['id'] as String;
      if (variants.containsKey(variantId)) {
        issues.add('Duplicate variant $id/$variantId');
      }
      final target = raw['target_item_count'] as int;
      variants[variantId] = target;
      declaredTotal += target;
    }
    if (declaredTotal != 20) issues.add('Variant quotas for $id must total 20');
    for (final entry in variants.entries) {
      if (group.where((item) => item.variantId == entry.key).length !=
          entry.value) {
        issues.add('Variant $id/${entry.key} requires ${entry.value} items');
      }
    }
    for (final variantId in group
        .map((item) => item.variantId)
        .toSet()
        .difference(variants.keys.toSet())) {
      issues.add('Extra variant $id/$variantId');
    }
  }
  return issues;
}

String _answerKey(AnswerRule rule) => switch (rule) {
      SingleChoiceRule r =>
        'choice:${r.options.firstWhere((option) => option.id == r.correctOptionId).label.trim()}',
      SentenceChoiceRule r =>
        'sentence:${r.options.firstWhere((option) => option.id == r.correctOptionId).label.trim()}',
      NumericRule r =>
        'numeric:${r.correctValue.canonical}:${r.displayedUnit ?? ''}',
      SpellingRule r => 'spelling:${r.target}',
      _ => 'unsupported:${rule.runtimeType}',
    };
