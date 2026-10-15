import 'dart:convert';
import 'dart:io';

import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/content/bank_quota_validator.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _catalogue() => jsonDecode(
      File('content/authoring/family_catalogue.json').readAsStringSync(),
    ) as Map<String, dynamic>;

// Synthetic draft coverage fixture; it is not a reviewed or releasable bank.
List<QuestionRevision> _draftBank(Map<String, dynamic> catalogue) {
  final result = <QuestionRevision>[];
  for (final family in catalogue['families'] as List) {
    final row = family as Map<String, dynamic>;
    final familyId = row['id'] as String;
    var ordinal = 0;
    for (final rawVariant in row['variants'] as List) {
      final variant = rawVariant as Map<String, dynamic>;
      final variantId = variant['id'] as String;
      for (var index = 0;
          index < (variant['target_item_count'] as int);
          index++) {
        final id = '$familyId-$variantId-$index';
        final format = variant['response_format'] ?? row['response_format'];
        final rule = switch (format) {
          'numeric' || 'numeric_with_displayed_unit' => NumericRule(
              correctValue: '${ordinal + 1}',
              displayedUnit:
                  format == 'numeric_with_displayed_unit' ? 'cm' : null,
              scoringPolicyVersion: 1,
            ),
          'spelling_entry' =>
            SpellingRule(target: 'word$ordinal', scoringPolicyVersion: 1),
          'sentence_choice' => SentenceChoiceRule(
              options: [
                ChoiceOption(id: 'a', label: 'Answer $ordinal'),
                ChoiceOption(id: 'b', label: 'Other $ordinal')
              ],
              correctOptionId: 'a',
              scoringPolicyVersion: 1,
            ),
          _ => SingleChoiceRule(
              options: [
                ChoiceOption(id: 'a', label: 'Answer $ordinal'),
                ChoiceOption(id: 'b', label: 'Other $ordinal')
              ],
              correctOptionId: 'a',
              scoringPolicyVersion: 1,
            ),
        };
        result.add(QuestionRevision(
          itemId: id,
          variantId: variantId,
          familyId: familyId,
          revision: 1,
          contentSchemaVersion: 1,
          bankVersion: 'synthetic-draft',
          topic: row['topic'] as String,
          domain: row['domain'] == 'numeracy'
              ? QuestionDomain.numeracy
              : QuestionDomain.conventions,
          difficulty: ordinal < 10
              ? QuestionDifficulty.introductory
              : QuestionDifficulty.developing,
          curriculumReferences: const ['draft-reference'],
          skillReferences: [row['skill'] as String],
          provenance: 'synthetic test fixture',
          license: 'synthetic test fixture',
          contentDigest: 'draft-$id',
          reviewRecordId: 'draft-only',
          prompt: 'Synthetic prompt $id',
          stimulusDescription: 'Synthetic stimulus $id',
          hint: 'Synthetic hint',
          explanation: 'Synthetic explanation',
          assets: const [],
          answerRule: rule,
        ));
        ordinal++;
      }
    }
  }
  return result;
}

QuestionRevision _copy(QuestionRevision source,
        {String? itemId,
        String? prompt,
        String? stimulusDescription,
        QuestionDifficulty? difficulty,
        String? variantId,
        AnswerRule? answerRule}) =>
    QuestionRevision(
      itemId: itemId ?? source.itemId,
      variantId: variantId ?? source.variantId,
      familyId: source.familyId,
      revision: source.revision,
      contentSchemaVersion: source.contentSchemaVersion,
      bankVersion: source.bankVersion,
      topic: source.topic,
      domain: source.domain,
      difficulty: difficulty ?? source.difficulty,
      curriculumReferences: source.curriculumReferences,
      skillReferences: source.skillReferences,
      provenance: source.provenance,
      license: source.license,
      contentDigest: source.contentDigest,
      reviewRecordId: source.reviewRecordId,
      prompt: prompt ?? source.prompt,
      stimulusDescription: stimulusDescription ?? source.stimulusDescription,
      hint: source.hint,
      explanation: source.explanation,
      assets: source.assets,
      answerRule: answerRule ?? source.answerRule,
    );

void main() {
  test('accepts exact synthetic draft quota coverage without release approval',
      () {
    final catalogue = _catalogue();
    expect(catalogue['release_bank'], false);
    expect(
        validateBankQuotas(items: _draftBank(catalogue), catalogue: catalogue),
        isEmpty);
  });

  test('rejects missing, extra and duplicate stable items', () {
    final catalogue = _catalogue();
    final bank = _draftBank(catalogue);
    expect(validateBankQuotas(items: bank.sublist(1), catalogue: catalogue),
        contains(contains('requires 20 items')));
    expect(
        validateBankQuotas(
            items: [...bank, _copy(bank.first, itemId: 'extra')],
            catalogue: catalogue),
        contains(contains('requires 440 distinct')));
    final duplicate = [...bank]..[1] =
        _copy(bank[1], itemId: bank.first.itemId);
    expect(validateBankQuotas(items: duplicate, catalogue: catalogue),
        contains(contains('Duplicate stable item ID')));
  });

  test('rejects difficulty and variant distribution even with 440 items', () {
    final catalogue = _catalogue();
    final bank = _draftBank(catalogue);
    final wrongDifficulty = [...bank]..[10] =
        _copy(bank[10], difficulty: QuestionDifficulty.introductory);
    expect(validateBankQuotas(items: wrongDifficulty, catalogue: catalogue),
        contains(contains('10 introductory and 10 developing')));
    final wrongVariant = [...bank]..[10] =
        _copy(bank[10], variantId: bank.first.variantId);
    expect(validateBankQuotas(items: wrongVariant, catalogue: catalogue),
        contains(contains('Variant N-PV-01')));
  });

  test('rejects repeated stimulus-answer combination under another ID', () {
    final catalogue = _catalogue();
    final bank = _draftBank(catalogue);
    final repeated = [...bank]..[1] = _copy(bank[1],
        prompt: bank.first.prompt,
        stimulusDescription: bank.first.stimulusDescription,
        answerRule: bank.first.answerRule);
    expect(validateBankQuotas(items: repeated, catalogue: catalogue),
        contains(contains('Repeated stimulus and answer')));
  });

  test('rejects missing or substituted catalogue family', () {
    final catalogue = _catalogue();
    final families = catalogue['families'] as List;
    families.removeLast();
    families.add({...families.last as Map<String, dynamic>, 'id': 'EXTRA'});
    final issues = validateBankQuotas(
        items: _draftBank(_catalogue()), catalogue: catalogue);
    expect(issues, contains(contains('Missing selected family')));
    expect(issues, contains(contains('Extra catalogue family')));
  });
}
