import 'package:ace_naplan5/domain/question.dart';
import 'package:ace_naplan5/domain/session/practice_selection.dart';
import 'package:flutter_test/flutter_test.dart';

SelectionCandidate item(String id, QuestionDomain domain,
        QuestionDifficulty difficulty, String family,
        {int revision = 1, String topic = 'topic'}) =>
    SelectionCandidate(
      itemId: id,
      revision: revision,
      familyId: family,
      topic: topic,
      domain: domain,
      difficulty: difficulty,
    );

void main() {
  final mixed = [
    for (final domain in QuestionDomain.values)
      for (final difficulty in QuestionDifficulty.values)
        for (var n = 0; n < 4; n++)
          item('${domain.name}-${difficulty.name}-$n', domain, difficulty,
              '${domain.name}-${n.isEven ? 'a' : 'b'}'),
  ];

  test('mixed quotas are deterministic across input order and seed repeats',
      () {
    PracticeSelection choose(Iterable<SelectionCandidate> source) =>
        selectPractice(
          candidates: source,
          exposedItemIds: {},
          reservedItemIds: {},
          mode: PracticeMode.fresh,
          seed: 77,
        );
    final first = choose(mixed);
    expect(first.items.map((e) => e.itemId).toList(),
        choose(mixed.reversed).items.map((e) => e.itemId).toList());
    expect(first.actualSize, 8);
    expect(first.shortfall, 0);
    expect(
        first.buckets
            .every((bucket) => bucket.target == 2 && bucket.missing == 0),
        isTrue);
    expect(first.items.map((e) => e.itemId).toSet().length, 8);
    expect(first.label, contains('Fresh'));
  });

  test('scarcity returns shorter fresh session with per-bucket shortfall', () {
    final available = mixed
        .where((item) =>
            item.domain == QuestionDomain.numeracy &&
            item.difficulty == QuestionDifficulty.introductory)
        .take(1)
        .toList();
    final result = selectPractice(
      candidates: available,
      exposedItemIds: {},
      reservedItemIds: {},
      mode: PracticeMode.fresh,
      seed: 1,
    );
    expect(result.actualSize, 1);
    expect(result.shortfall, 7);
    expect(result.buckets.map((e) => e.missing), [1, 2, 2, 2]);
  });

  test('review sees exposed IDs; fresh excludes revisions and reservations',
      () {
    final revised = item(
        'stable', QuestionDomain.numeracy, QuestionDifficulty.introductory, 'a',
        revision: 2);
    final reserved = item('reserved', QuestionDomain.numeracy,
        QuestionDifficulty.introductory, 'a');
    final fresh = selectPractice(
      candidates: [revised, reserved],
      exposedItemIds: {'stable'},
      reservedItemIds: {'reserved'},
      mode: PracticeMode.fresh,
      seed: 2,
    );
    expect(fresh.actualSize, 0);
    expect(fresh.shortfall, 8);
    final review = selectPractice(
      candidates: [revised, reserved],
      exposedItemIds: {'stable', 'reserved'},
      reservedItemIds: {'reserved'},
      mode: PracticeMode.review,
      seed: 2,
    );
    expect(review.items.single.itemId, 'stable');
    expect(review.items.single.revision, 2);
    expect(review.label, contains('seen before'));
  });

  test('two-family topic allocates two of each difficulty per family', () {
    final source = [
      for (final family in ['one', 'two'])
        for (final difficulty in QuestionDifficulty.values)
          for (var n = 0; n < 3; n++)
            item('$family-${difficulty.name}-$n', QuestionDomain.numeracy,
                difficulty, family),
      item('wrong-topic', QuestionDomain.numeracy,
          QuestionDifficulty.introductory, 'one',
          topic: 'other'),
    ];
    final result = selectPractice(
      candidates: source,
      exposedItemIds: {},
      reservedItemIds: {},
      mode: PracticeMode.fresh,
      topic: 'topic',
      topicFamilyIds: {'two', 'one'},
      seed: 4,
    );
    expect(result.actualSize, 8);
    expect(result.buckets.length, 4);
    expect(result.buckets.every((bucket) => bucket.missing == 0), isTrue);
    expect(result.items.where((e) => e.familyId == 'one').length, 4);
    expect(result.items.where((e) => e.familyId == 'two').length, 4);
  });

  test('avoids identical preceding set when same-bucket alternative exists',
      () {
    final first = selectPractice(
      candidates: mixed,
      exposedItemIds: {},
      reservedItemIds: {},
      mode: PracticeMode.fresh,
      seed: 9,
    );
    final second = selectPractice(
      candidates: mixed,
      exposedItemIds: {},
      reservedItemIds: {},
      mode: PracticeMode.fresh,
      seed: 9,
      precedingItemIds: first.items.map((e) => e.itemId).toSet(),
    );
    expect(second.repeatsPrecedingSet, isFalse);
    expect(second.items.map((entry) => entry.itemId).toSet().length,
        second.actualSize);
    expect(second.actualSize, 8);
    final unavoidable = selectPractice(
      candidates: first.items,
      exposedItemIds: {},
      reservedItemIds: {},
      mode: PracticeMode.fresh,
      seed: 9,
      precedingItemIds: first.items.map((e) => e.itemId).toSet(),
    );
    expect(unavoidable.repeatsPrecedingSet, isTrue);
  });

  test('coordinated swaps avoid a repeat while keeping families balanced', () {
    final source = [
      item(
          'a-i', QuestionDomain.numeracy, QuestionDifficulty.introductory, 'A'),
      item(
          'b-i', QuestionDomain.numeracy, QuestionDifficulty.introductory, 'B'),
      item('z-i', QuestionDomain.numeracy, QuestionDifficulty.introductory, 'C',
          revision: 2),
      item('a-d', QuestionDomain.numeracy, QuestionDifficulty.developing, 'C'),
      item('b-d', QuestionDomain.numeracy, QuestionDifficulty.developing, 'D'),
      item('z-d', QuestionDomain.numeracy, QuestionDifficulty.developing, 'A',
          revision: 3),
    ];
    PracticeSelection choose(
            Iterable<SelectionCandidate> candidates, Set<String> preceding) =>
        selectPractice(
          candidates: candidates,
          exposedItemIds: {},
          reservedItemIds: {},
          mode: PracticeMode.fresh,
          seed: 1,
          precedingItemIds: preceding,
        );

    final first = choose(source, {});
    final preceding = first.items.map((entry) => entry.itemId).toSet();
    expect(preceding, {'a-i', 'b-i', 'a-d', 'b-d'});
    final second = choose(source, preceding);
    expect(second.items.map((entry) => entry.itemId).toSet(),
        {'z-i', 'b-i', 'z-d', 'b-d'});
    expect(second.repeatsPrecedingSet, isFalse);
    expect(second.shortfall, 4);
    expect(second.items.map((entry) => entry.familyId).toSet(),
        {'A', 'B', 'C', 'D'});
    expect(
        second.items.firstWhere((entry) => entry.itemId == 'z-i').revision, 2);
    expect(
        second.items.firstWhere((entry) => entry.itemId == 'z-d').revision, 3);
    expect(
        choose(source.reversed, preceding).items.map((entry) => entry.itemId),
        second.items.map((entry) => entry.itemId));

    final exhausted = choose(first.items, preceding);
    expect(exhausted.repeatsPrecedingSet, isTrue);
    expect(exhausted.items.map((entry) => entry.itemId).toSet(), preceding);
  });

  test('mixed selection balances families across difficulty buckets', () {
    final source = [
      for (var n = 0; n < 2; n++)
        item('a-i-$n', QuestionDomain.numeracy, QuestionDifficulty.introductory,
            'a'),
      for (var n = 0; n < 2; n++)
        item('b-i-$n', QuestionDomain.numeracy, QuestionDifficulty.introductory,
            'b'),
      for (var n = 0; n < 4; n++)
        item('b-d-$n', QuestionDomain.numeracy, QuestionDifficulty.developing,
            'b'),
    ];
    final result = selectPractice(
      candidates: source,
      exposedItemIds: {},
      reservedItemIds: {},
      mode: PracticeMode.fresh,
      seed: 3,
    );
    expect(result.items.where((item) => item.familyId == 'a').length, 2);
    expect(result.items.where((item) => item.familyId == 'b').length, 2);
    expect(result.actualSize, 4);
  });

  test('rejects duplicate stable IDs across revisions and invalid policy', () {
    final initial = mixed.first;
    expect(
        () => selectPractice(
              candidates: [
                initial,
                item(initial.itemId, initial.domain, initial.difficulty,
                    initial.familyId,
                    revision: 2)
              ],
              exposedItemIds: {},
              reservedItemIds: {},
              mode: PracticeMode.fresh,
              seed: 1,
            ),
        throwsArgumentError);
    expect(
        () => selectPractice(
              candidates: [],
              exposedItemIds: {},
              reservedItemIds: {},
              mode: PracticeMode.fresh,
              seed: 1,
              topic: 'topic',
              topicFamilyIds: {'one'},
            ),
        throwsArgumentError);
  });
}
