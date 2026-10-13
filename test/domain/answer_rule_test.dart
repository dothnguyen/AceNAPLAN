import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final options = [
    ChoiceOption(id: 'a', label: 'First'),
    ChoiceOption(id: 'b', label: 'Second'),
  ];

  for (final create in <AnswerRule Function()>[
    () => SingleChoiceRule(
          options: options,
          correctOptionId: 'a',
          scoringPolicyVersion: 1,
        ),
    () => SentenceChoiceRule(
          options: options,
          correctOptionId: 'a',
          scoringPolicyVersion: 1,
        ),
  ]) {
    test('choice rules distinguish correct, wrong and invalid', () {
      final rule = create();
      expect((rule.score(const ChoiceResponse('a')) as ScoredAnswer).isCorrect,
          isTrue);
      expect((rule.score(const ChoiceResponse('b')) as ScoredAnswer).isCorrect,
          isFalse);
      expect(rule.score(const ChoiceResponse('missing')), isA<InvalidAnswer>());
      expect(rule.score(const ChoiceResponse(' ')), isA<InvalidAnswer>());
      expect(rule.score(const TextResponse('a')), isA<InvalidAnswer>());
    });
  }

  test('choice IDs and responses have a 128 code unit bound', () {
    final boundary = 'x' * 128;
    expect(() => ChoiceOption(id: 'x' * 129, label: 'Too long'),
        throwsArgumentError);
    final rule = SingleChoiceRule(options: [
      ChoiceOption(id: boundary, label: 'Boundary'),
      ChoiceOption(id: 'b', label: 'Other')
    ], correctOptionId: boundary, scoringPolicyVersion: 1);
    expect((rule.score(ChoiceResponse(boundary)) as ScoredAnswer).isCorrect,
        isTrue);
    expect((rule.score(ChoiceResponse('x' * 129)) as InvalidAnswer).reason,
        InvalidAnswerReason.tooLong);
  });

  test('choice authoring validates key and freezes options', () {
    expect(
      () => SingleChoiceRule(
        options: [options.first, options.first],
        correctOptionId: 'a',
        scoringPolicyVersion: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => SentenceChoiceRule(
        options: options,
        correctOptionId: 'x',
        scoringPolicyVersion: 1,
      ),
      throwsArgumentError,
    );
    final input = [...options];
    final rule = SingleChoiceRule(
      options: input,
      correctOptionId: 'a',
      scoringPolicyVersion: 1,
    );
    input.clear();
    expect(rule.options, hasLength(2));
    expect(() => rule.options.clear(), throwsUnsupportedError);
  });

  test('decimal equivalence is exact beyond JavaScript Number range', () {
    final rule = NumericRule(
      correctValue: '9007199254740993.10',
      scoringPolicyVersion: 2,
      displayedUnit: 'cm',
    );
    final scored = rule.score(const TextResponse('+09007199254740993.100'))
        as ScoredAnswer;
    expect(scored.isCorrect, isTrue);
    expect(scored.normalizedResponse, '9007199254740993.1');
    expect(scored.scoringPolicyVersion, 2);
    expect(
        (rule.score(const TextResponse('9007199254740992.1')) as ScoredAnswer)
            .isCorrect,
        isFalse);
    expect(rule.displayedUnit, 'cm');
    expect(rule.score(const TextResponse('9007199254740993.1 cm')),
        isA<InvalidAnswer>());
    expect(ExactDecimal.parse('0.1'), ExactDecimal.parse('0.10'));
    expect(ExactDecimal.parse('1.00'), ExactDecimal.parse('0001'));
    expect(ExactDecimal.parse('-0.00')!.canonical, '0');
    expect(ExactDecimal.parse('-.5')!.canonical, '-0.5');
  });

  test('numeric bounds, syntax and authoring keys', () {
    final rule = NumericRule(correctValue: '1', scoringPolicyVersion: 1);
    for (final value in [
      '1.',
      '1e0',
      'NaN',
      'Infinity',
      '1,000',
      '1/1',
      '1 0',
      r'$1'
    ]) {
      expect(rule.score(TextResponse(value)), isA<InvalidAnswer>(),
          reason: value);
    }
    expect(rule.score(const TextResponse(' ')), isA<InvalidAnswer>());
    expect(rule.score(const ChoiceResponse('1')), isA<InvalidAnswer>());
    expect(rule.score(TextResponse(List.filled(129, '1').join())),
        isA<InvalidAnswer>());
    expect(rule.score(TextResponse('${List.filled(32, '0').join()}.1')),
        isA<ScoredAnswer>());
    expect(rule.score(TextResponse('0.${List.filled(33, '1').join()}')),
        isA<InvalidAnswer>());
    expect(rule.score(TextResponse(List.filled(65, '1').join())),
        isA<InvalidAnswer>());
    expect(() => NumericRule(correctValue: '1e0', scoringPolicyVersion: 1),
        throwsArgumentError);
    expect(
        () => NumericRule(
            correctValue: '1', scoringPolicyVersion: 1, displayedUnit: ' '),
        throwsArgumentError);
  });

  test('spelling trims and folds case but preserves punctuation and accents',
      () {
    final alternatives = ['wellbeing'];
    final rule = SpellingRule(
      target: 'Well-being',
      alternatives: alternatives,
      scoringPolicyVersion: 1,
    );
    alternatives.clear();
    expect(rule.alternatives, ['wellbeing']);
    expect(() => rule.alternatives.add('x'), throwsUnsupportedError);
    expect(
        (rule.score(const TextResponse(' WELL-BEING ')) as ScoredAnswer)
            .isCorrect,
        isTrue);
    expect(
        (rule.score(const TextResponse('wellbeing')) as ScoredAnswer).isCorrect,
        isTrue);
    expect(
        (rule.score(const TextResponse('well being')) as ScoredAnswer)
            .isCorrect,
        isFalse);
    final accent = SpellingRule(target: 'café', scoringPolicyVersion: 1);
    expect((accent.score(const TextResponse('cafe')) as ScoredAnswer).isCorrect,
        isFalse);
    expect(accent.score(const TextResponse(' ')), isA<InvalidAnswer>());
    expect(accent.score(TextResponse(List.filled(129, 'x').join())),
        isA<InvalidAnswer>());
    expect(accent.score(const ChoiceResponse('x')), isA<InvalidAnswer>());
    expect(() => SpellingRule(target: ' ', scoringPolicyVersion: 1),
        throwsArgumentError);
    expect(
        () => SpellingRule(
            target: 'a', alternatives: ['A'], scoringPolicyVersion: 1),
        throwsArgumentError);
  });

  test('question metadata validates and freezes nested collections', () {
    final refs = ['AC9M5N01'];
    final assets = [
      QuestionAsset(
          id: 'chart', digest: 'sha256-value', description: 'Chart text')
    ];
    QuestionRevision make() => QuestionRevision(
          itemId: 'item-1',
          variantId: 'v-1',
          familyId: 'family-1',
          revision: 1,
          contentSchemaVersion: 1,
          bankVersion: 'bank-1',
          topic: 'numbers',
          domain: QuestionDomain.numeracy,
          difficulty: QuestionDifficulty.introductory,
          curriculumReferences: refs,
          skillReferences: ['place value'],
          provenance: 'source',
          license: 'licensed',
          contentDigest: 'digest',
          reviewRecordId: 'review-1',
          prompt: 'Choose.',
          stimulusDescription: 'Two answers',
          hint: 'Think about place value.',
          explanation: 'The first answer is correct.',
          assets: assets,
          answerRule: SingleChoiceRule(
              options: options, correctOptionId: 'a', scoringPolicyVersion: 1),
        );
    final question = make();
    refs.clear();
    assets.clear();
    expect(question.curriculumReferences, ['AC9M5N01']);
    expect(question.assets.single.id, 'chart');
    expect(() => question.curriculumReferences.clear(), throwsUnsupportedError);
    expect(() => question.assets.clear(), throwsUnsupportedError);
    expect(
        () => QuestionRevision(
              itemId: '',
              variantId: question.variantId,
              familyId: question.familyId,
              revision: 1,
              contentSchemaVersion: 1,
              bankVersion: question.bankVersion,
              topic: question.topic,
              domain: question.domain,
              difficulty: question.difficulty,
              curriculumReferences: ['x'],
              skillReferences: ['y'],
              provenance: question.provenance,
              license: question.license,
              contentDigest: question.contentDigest,
              reviewRecordId: question.reviewRecordId,
              prompt: question.prompt,
              stimulusDescription: question.stimulusDescription,
              hint: question.hint,
              explanation: question.explanation,
              assets: const [],
              answerRule: question.answerRule,
            ),
        throwsArgumentError);
  });
}
