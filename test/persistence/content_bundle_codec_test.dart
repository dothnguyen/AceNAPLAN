import 'dart:convert';

import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:ace_naplan5/infrastructure/persistence/content_bundle_codec.dart';
import 'package:flutter_test/flutter_test.dart';

const codec = ContentBundleCodec();

QuestionRevision draft(AnswerRule rule) => QuestionRevision(
      itemId: 'draft-item',
      variantId: 'draft-variant',
      familyId: 'draft-family',
      revision: 2,
      contentSchemaVersion: 1,
      bankVersion: 'draft-bank-2',
      topic: 'place value',
      domain: QuestionDomain.numeracy,
      difficulty: QuestionDifficulty.developing,
      curriculumReferences: const ['draft-curriculum'],
      skillReferences: const ['draft-skill'],
      provenance: 'draft author',
      license: 'draft rights',
      contentDigest: 'draft-digest',
      reviewRecordId: 'draft-review-reference',
      prompt: 'Draft prompt?',
      stimulusDescription: 'Draft accessible stimulus',
      hint: 'Draft hint',
      explanation: 'Draft explanation',
      assets: [
        QuestionAsset(
            id: 'draft-audio',
            digest: 'asset-digest',
            description: 'Draft recording')
      ],
      answerRule: rule,
    );

void main() {
  final rules = <AnswerRule>[
    SingleChoiceRule(options: [
      ChoiceOption(id: 'a', label: 'One'),
      ChoiceOption(id: 'b', label: 'Two')
    ], correctOptionId: 'b', scoringPolicyVersion: 3),
    SentenceChoiceRule(options: [
      ChoiceOption(id: 'first', label: 'First.'),
      ChoiceOption(id: 'second', label: 'Second.')
    ], correctOptionId: 'first', scoringPolicyVersion: 4),
    NumericRule(
        correctValue: '12.50', displayedUnit: 'cm', scoringPolicyVersion: 5),
    SpellingRule(
        target: 'Colour',
        alternatives: const ['Color'],
        scoringPolicyVersion: 6),
  ];

  for (final rule in rules) {
    test(
        '${rule.runtimeType} draft round trip preserves all content and scoring',
        () {
      final source = draft(rule);
      final encoded = codec.encodeQuestion(source);
      final decoded = codec.decodeQuestion(encoded);
      expect(codec.encodeQuestion(decoded), encoded);
      expect(decoded.contentDigest, 'draft-digest');
      expect(decoded.reviewRecordId, 'draft-review-reference');
      expect(decoded.assets.single.digest, 'asset-digest');
      expect(decoded.curriculumReferences, ['draft-curriculum']);
      expect(decoded.skillReferences, ['draft-skill']);
      expect(decoded.bankVersion, 'draft-bank-2');
      expect(decoded.revision, 2);
      expect(
          decoded.answerRule.scoringPolicyVersion, rule.scoringPolicyVersion);
      expect(
          codec.encodeAnswerRule(
              codec.decodeAnswerRule(codec.encodeAnswerRule(rule))),
          codec.encodeAnswerRule(rule));
      expect(
          codec.encodeAssets(
              codec.decodeAssets(codec.encodeAssets(source.assets))),
          codec.encodeAssets(source.assets));
    });
  }

  test('choice and numeric rules retain correct answer behavior', () {
    final choice = codec.decodeAnswerRule(codec.encodeAnswerRule(rules.first));
    expect((choice.score(const ChoiceResponse('b')) as ScoredAnswer).isCorrect,
        isTrue);
    final sentence = codec.decodeAnswerRule(codec.encodeAnswerRule(rules[1]));
    expect(
        (sentence.score(const ChoiceResponse('second')) as ScoredAnswer)
            .isCorrect,
        isFalse);
    final numeric = codec.decodeAnswerRule(codec.encodeAnswerRule(rules[2]));
    expect(
        (numeric.score(const TextResponse('12.5')) as ScoredAnswer).isCorrect,
        isTrue);
    final spelling = codec.decodeAnswerRule(codec.encodeAnswerRule(rules[3]));
    expect(
        (spelling.score(const TextResponse(' COLOR ')) as ScoredAnswer)
            .isCorrect,
        isTrue);
  });

  test('unsupported versions, tags, missing and incompatible fields fail', () {
    final base = jsonDecode(codec.encodeQuestion(draft(rules.first)))
        as Map<String, dynamic>;
    for (final change in <void Function(Map<String, dynamic>)>[
      (m) => m['schemaVersion'] = 2,
      (m) => m['contentSchemaVersion'] = 2,
      (m) => m['domain'] = 'reading',
      (m) => m['revision'] = '2',
      (m) => m.remove('reviewRecordId'),
      (m) => m['unexpected'] = true,
      (m) => m['assets'] = [
            {'id': 'x', 'digest': 12, 'description': 'bad'}
          ],
      (m) => m['answerRule']['type'] = 'multipleSelection',
      (m) => m['answerRule']['correctOptionId'] = 'missing',
      (m) => m['answerRule']['options'][0]['id'] = 'b',
    ]) {
      final mutated = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      change(mutated);
      expect(() => codec.decodeQuestion(jsonEncode(mutated)),
          throwsA(isA<FormatException>()));
    }
  });

  test('encoding an unsupported content schema fails before import', () {
    final q = draft(rules.first);
    final unsupported = QuestionRevision(
      itemId: q.itemId,
      variantId: q.variantId,
      familyId: q.familyId,
      revision: q.revision,
      contentSchemaVersion: 2,
      bankVersion: q.bankVersion,
      topic: q.topic,
      domain: q.domain,
      difficulty: q.difficulty,
      curriculumReferences: q.curriculumReferences,
      skillReferences: q.skillReferences,
      provenance: q.provenance,
      license: q.license,
      contentDigest: q.contentDigest,
      reviewRecordId: q.reviewRecordId,
      prompt: q.prompt,
      stimulusDescription: q.stimulusDescription,
      hint: q.hint,
      explanation: q.explanation,
      assets: q.assets,
      answerRule: q.answerRule,
    );
    expect(() => codec.encodeQuestion(unsupported),
        throwsA(isA<FormatException>()));
  });

  test('standalone rule and asset JSON reject malformed payloads', () {
    for (final source in [
      '{',
      '{}',
      '{"schemaVersion":1,"scoringPolicyVersion":1,"type":"numeric",'
          '"correctValue":"NaN","displayedUnit":null}',
      '{"schemaVersion":1,"scoringPolicyVersion":"1","type":"spelling",'
          '"target":"word","alternatives":[]}',
    ]) {
      expect(() => codec.decodeAnswerRule(source),
          throwsA(isA<FormatException>()));
    }
    expect(() => codec.decodeAssets('[{"id":"x"}]'),
        throwsA(isA<FormatException>()));
    expect(() => codec.decodeAssets('{'), throwsA(isA<FormatException>()));
  });
}
