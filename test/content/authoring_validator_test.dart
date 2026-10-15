import 'dart:convert';
import 'dart:io';

import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/content/authoring_validator.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> catalogue() => jsonDecode(
      File('content/authoring/family_catalogue.json').readAsStringSync(),
    ) as Map<String, dynamic>;

QuestionRevision item({
  String id = 'item-1',
  String family = 'N-PV-01',
  String variant = 'whole_number',
  int revision = 1,
  String topic = 'place_value',
  QuestionDomain domain = QuestionDomain.numeracy,
  QuestionDifficulty difficulty = QuestionDifficulty.introductory,
  List<String> skills = const ['Identify the value of a highlighted digit'],
  AnswerRule? rule,
}) =>
    QuestionRevision(
      itemId: id,
      variantId: variant,
      familyId: family,
      revision: revision,
      contentSchemaVersion: 1,
      bankVersion: 'draft-fixture-1',
      topic: topic,
      domain: domain,
      difficulty: difficulty,
      curriculumReferences: const ['draft-curriculum-reference'],
      skillReferences: skills,
      provenance: 'test fixture',
      license: 'test fixture',
      contentDigest: 'draft-digest-$id-$revision',
      reviewRecordId: 'draft-review-record',
      prompt: 'What is the value of 3 in 34?',
      stimulusDescription: 'The number 34 has a highlighted 3.',
      hint: 'Think about tens.',
      explanation: 'The 3 means three tens, or 30.',
      assets: const [],
      answerRule:
          rule ?? NumericRule(correctValue: '30', scoringPolicyVersion: 1),
    );

void main() {
  test('valid draft items and stable corrections pass structural checks', () {
    final items = [item(), item(revision: 2)];
    expect(
        validateAuthoredItems(items: items, catalogue: catalogue()), isEmpty);
    expect(catalogue()['release_bank'], false);
  });

  test('rejects duplicate revision and unstable family or variant identity',
      () {
    final items = [
      item(),
      item(),
      item(revision: 2, variant: 'decimal'),
    ];
    final issues = validateAuthoredItems(items: items, catalogue: catalogue());
    expect(issues, contains(contains('Duplicate item revision')));
    expect(issues, contains(contains('Unstable item identity')));
  });

  test('rejects unknown family or variant and mismatched topic, skill, domain',
      () {
    final items = [
      item(id: 'a', family: 'unknown'),
      item(id: 'b', variant: 'unknown'),
      item(id: 'c', topic: 'chance'),
      item(id: 'd', domain: QuestionDomain.conventions),
      item(id: 'e', skills: const ['unrelated skill']),
    ];
    final issues = validateAuthoredItems(items: items, catalogue: catalogue());
    for (final fragment in [
      'Unknown family',
      'Unknown family variant',
      'Family domain or topic mismatch',
      'Missing catalogue skill',
    ]) {
      expect(issues, contains(contains(fragment)));
    }
  });

  test('rejects unsupported difficulty and malformed catalogue', () {
    final source = catalogue();
    final families = source['families'] as List;
    final family = families.first as Map<String, dynamic>;
    family['difficulty_targets'] = {'introductory': 10};
    expect(
      validateAuthoredItems(
        items: [item(difficulty: QuestionDifficulty.developing)],
        catalogue: source,
      ),
      contains(contains('Unsupported difficulty')),
    );
    expect(
      validateAuthoredItems(items: [item()], catalogue: {}),
      contains(contains('Malformed family catalogue')),
    );
  });

  test('rejects incompatible formats including composite variant format', () {
    final choice = SingleChoiceRule(
      options: [
        ChoiceOption(id: 'a', label: 'A'),
        ChoiceOption(id: 'b', label: 'B')
      ],
      correctOptionId: 'a',
      scoringPolicyVersion: 1,
    );
    final items = [
      item(id: 'a', rule: choice),
      item(
        id: 'b',
        family: 'N-MT-01',
        variant: 'within_hour',
        topic: 'measurement_and_time',
        skills: const ['Calculate elapsed time without date rollover'],
      ),
      item(
        id: 'c',
        family: 'N-DT-02',
        variant: 'comparison',
        topic: 'data_interpretation',
        skills: const ['Compare values in a table'],
      ),
    ];
    expect(
      validateAuthoredItems(items: items, catalogue: catalogue())
          .where((issue) => issue.contains('Response format mismatch')),
      hasLength(3),
    );
  });

  test('malformed keys and missing metadata are rejected by typed models', () {
    expect(
      () => SingleChoiceRule(
        options: [
          ChoiceOption(id: 'a', label: 'A'),
          ChoiceOption(id: 'b', label: 'B')
        ],
        correctOptionId: 'missing',
        scoringPolicyVersion: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => NumericRule(correctValue: 'NaN', scoringPolicyVersion: 1),
      throwsArgumentError,
    );
    expect(
      () => SpellingRule(target: ' ', scoringPolicyVersion: 1),
      throwsArgumentError,
    );
    expect(() => item(skills: const []), throwsArgumentError);
  });
}
