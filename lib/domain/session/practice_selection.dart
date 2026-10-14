import '../question.dart';

enum PracticeMode { fresh, review }

/// The caller supplies only active, reviewed, compatible bank revisions.
/// Selection does not validate content approval or write reservations.
final class SelectionCandidate {
  SelectionCandidate({
    required this.itemId,
    required this.revision,
    required this.familyId,
    required this.topic,
    required this.domain,
    required this.difficulty,
  }) {
    if (itemId.trim().isEmpty ||
        familyId.trim().isEmpty ||
        topic.trim().isEmpty ||
        revision < 1) {
      throw ArgumentError('Candidate IDs, topic and revision must be valid.');
    }
  }

  final String itemId;
  final int revision;
  final String familyId;
  final String topic;
  final QuestionDomain domain;
  final QuestionDifficulty difficulty;
}

final class SelectionBucket {
  const SelectionBucket(
      {required this.key, required this.target, required this.missing});

  final String key;
  final int target;
  final int missing;
}

final class PracticeSelection {
  PracticeSelection({
    required this.mode,
    required List<SelectionCandidate> items,
    required List<SelectionBucket> buckets,
    required this.repeatsPrecedingSet,
  })  : items = List.unmodifiable(items),
        buckets = List.unmodifiable(buckets);

  final PracticeMode mode;
  final List<SelectionCandidate> items;
  final List<SelectionBucket> buckets;
  final bool repeatsPrecedingSet;
  int get actualSize => items.length;
  int get shortfall => buckets.fold(0, (sum, bucket) => sum + bucket.missing);
  String get label => mode == PracticeMode.fresh
      ? 'Fresh — new questions'
      : 'Review — questions you have seen before';
}

/// A pure selection request. Topic mode requires exactly two distinct families.
/// Stable item IDs, rather than revisions, define exposure and reservations.
PracticeSelection selectPractice({
  required Iterable<SelectionCandidate> candidates,
  required Set<String> exposedItemIds,
  required Set<String> reservedItemIds,
  required PracticeMode mode,
  required int seed,
  String? topic,
  Set<String>? topicFamilyIds,
  Set<String> precedingItemIds = const {},
}) {
  final topicMode = topic != null;
  if (topicMode != (topicFamilyIds != null) ||
      (topicMode &&
          (topic.trim().isEmpty ||
              topicFamilyIds!.length != 2 ||
              topicFamilyIds.any((id) => id.trim().isEmpty)))) {
    throw ArgumentError('Topic selection requires a topic and two families.');
  }

  final all = candidates.toList();
  final ids = <String>{};
  for (final candidate in all) {
    if (!ids.add(candidate.itemId)) {
      throw ArgumentError('Duplicate stable item ID: ${candidate.itemId}');
    }
  }

  final eligible = all.where((candidate) {
    if (reservedItemIds.contains(candidate.itemId)) {
      return false;
    }
    if (exposedItemIds.contains(candidate.itemId) !=
        (mode == PracticeMode.review)) {
      return false;
    }
    if (topicMode) {
      return candidate.topic == topic &&
          topicFamilyIds!.contains(candidate.familyId);
    }
    return true;
  }).toList();

  final keys = topicMode
      ? [
          for (final family in (topicFamilyIds!.toList()..sort()))
            for (final difficulty in QuestionDifficulty.values)
              '$family/${difficulty.name}'
        ]
      : [
          for (final domain in QuestionDomain.values)
            for (final difficulty in QuestionDifficulty.values)
              '${domain.name}/${difficulty.name}'
        ];
  String keyOf(SelectionCandidate item) => topicMode
      ? '${item.familyId}/${item.difficulty.name}'
      : '${item.domain.name}/${item.difficulty.name}';

  final byKey = <String, List<SelectionCandidate>>{};
  for (final key in keys) {
    byKey[key] = [];
  }
  for (final item in eligible) {
    byKey[keyOf(item)]?.add(item);
  }
  for (final bucket in byKey.values) {
    bucket.sort((a, b) {
      final rank = _rank(seed, a.itemId).compareTo(_rank(seed, b.itemId));
      return rank != 0 ? rank : a.itemId.compareTo(b.itemId);
    });
  }

  final selected = <SelectionCandidate>[];
  final selectedIds = <String>{};
  final familyCounts = <String, int>{};
  final buckets = <SelectionBucket>[];
  for (final key in keys) {
    final pool = byKey[key]!;
    final count = pool.length < 2 ? pool.length : 2;
    for (var i = 0; i < count; i++) {
      // Rotate families within a mixed domain while respecting difficulty.
      var index = 0;
      if (!topicMode) {
        for (var j = 1; j < pool.length; j++) {
          if ((familyCounts[pool[j].familyId] ?? 0) <
              (familyCounts[pool[index].familyId] ?? 0)) {
            index = j;
          }
        }
      }
      final item = pool.removeAt(index);
      selected.add(item);
      selectedIds.add(item.itemId);
      familyCounts[item.familyId] = (familyCounts[item.familyId] ?? 0) + 1;
    }
    buckets.add(SelectionBucket(key: key, target: 2, missing: 2 - count));
  }

  if (!topicMode) {
    // Rebalance across difficulty buckets when a family is scarce in one.
    for (final domain in QuestionDomain.values) {
      final families = eligible
          .where((item) => item.domain == domain)
          .map((item) => item.familyId)
          .toSet();
      var improved = true;
      while (improved) {
        improved = false;
        final counts = {for (final family in families) family: 0};
        for (final item in selected.where((item) => item.domain == domain)) {
          counts[item.familyId] = (counts[item.familyId] ?? 0) + 1;
        }
        for (var index = 0; index < selected.length && !improved; index++) {
          final old = selected[index];
          if (old.domain != domain) {
            continue;
          }
          for (final replacement in byKey[keyOf(old)]!) {
            if (replacement.familyId == old.familyId) {
              continue;
            }
            if (counts[old.familyId]! <= counts[replacement.familyId]! + 1) {
              continue;
            }
            selectedIds.remove(old.itemId);
            selected[index] = replacement;
            selectedIds.add(replacement.itemId);
            byKey[keyOf(old)]!
              ..remove(replacement)
              ..add(old);
            improved = true;
            break;
          }
        }
      }
    }
  }

  bool repeats() =>
      selectedIds.length == precedingItemIds.length &&
      selectedIds.containsAll(precedingItemIds);
  if (selected.isNotEmpty && repeats()) {
    // Candidates with the same bucket and family have the same effect on
    // balance. Keep their first ranked representative for bounded repair.
    final swaps = <_SelectionSwap>[];
    final familiesByDomain = <QuestionDomain, Set<String>>{};
    for (final item in eligible) {
      (familiesByDomain[item.domain] ??= <String>{}).add(item.familyId);
    }
    for (var index = 0; index < selected.length; index++) {
      final seenFamilies = <String>{};
      for (final alternative in byKey[keyOf(selected[index])]!) {
        if (precedingItemIds.contains(alternative.itemId) ||
            !seenFamilies.add(alternative.familyId)) {
          continue;
        }
        swaps.add(_SelectionSwap(index, alternative));
      }
    }

    int spread(QuestionDomain domain, _SelectionSwap first,
        [_SelectionSwap? second]) {
      final counts = {
        for (final family in familiesByDomain[domain]!) family: 0,
      };
      for (var index = 0; index < selected.length; index++) {
        final item = index == first.index
            ? first.alternative
            : index == second?.index
                ? second!.alternative
                : selected[index];
        if (item.domain == domain) {
          counts[item.familyId] = counts[item.familyId]! + 1;
        }
      }
      final values = counts.values;
      var minimum = selected.length;
      var maximum = 0;
      for (final value in values) {
        if (value < minimum) {
          minimum = value;
        }
        if (value > maximum) {
          maximum = value;
        }
      }
      return maximum - minimum;
    }

    final allowedSpread = <QuestionDomain, int>{};
    if (!topicMode) {
      for (final domain in familiesByDomain.keys) {
        final counts = {
          for (final family in familiesByDomain[domain]!) family: 0,
        };
        for (final item in selected) {
          if (item.domain == domain) {
            counts[item.familyId] = counts[item.familyId]! + 1;
          }
        }
        var minimum = selected.length;
        var maximum = 0;
        for (final value in counts.values) {
          if (value < minimum) {
            minimum = value;
          }
          if (value > maximum) {
            maximum = value;
          }
        }
        allowedSpread[domain] = maximum - minimum > 1 ? maximum - minimum : 1;
      }
    }

    bool balanced(_SelectionSwap first, [_SelectionSwap? second]) =>
        topicMode ||
        spread(first.alternative.domain, first, second) <=
            allowedSpread[first.alternative.domain]!;

    void apply(_SelectionSwap swap) {
      selectedIds.remove(selected[swap.index].itemId);
      selected[swap.index] = swap.alternative;
      selectedIds.add(swap.alternative.itemId);
    }

    for (final swap in swaps) {
      if (balanced(swap)) {
        apply(swap);
        break;
      }
    }
    if (repeats() && !topicMode) {
      // A paired repair can move a family between two difficulty buckets.
      // Only a swap touching the first swap's lost or gained family can
      // repair a failed single swap.
      final byOldFamily = <String, List<_SelectionSwap>>{};
      final byNewFamily = <String, List<_SelectionSwap>>{};
      for (final swap in swaps) {
        final domain = swap.alternative.domain.name;
        final old = selected[swap.index].familyId;
        (byOldFamily['$domain/$old'] ??= []).add(swap);
        (byNewFamily['$domain/${swap.alternative.familyId}'] ??= []).add(swap);
      }
      var repaired = false;
      for (final first in swaps) {
        final domain = first.alternative.domain.name;
        final old = selected[first.index].familyId;
        final partners = <_SelectionSwap>{
          ...?byOldFamily['$domain/${first.alternative.familyId}'],
          ...?byNewFamily['$domain/$old'],
        };
        for (final second in partners) {
          if (first.index == second.index ||
              first.alternative.itemId == second.alternative.itemId ||
              !balanced(first, second)) {
            continue;
          }
          apply(first);
          apply(second);
          repaired = true;
          break;
        }
        if (repaired) {
          break;
        }
      }
      if (!repaired) {
        // More than two transfers can form a family cycle. Follow only
        // families currently selected in this domain. Each selected slot
        // contributes at most one representative per selected family.
        final cycleByOldFamily = <String, List<_SelectionSwap>>{};
        for (final swap in swaps) {
          final domain = swap.alternative.domain.name;
          if (!byOldFamily
              .containsKey('$domain/${swap.alternative.familyId}')) {
            continue;
          }
          final old = selected[swap.index].familyId;
          (cycleByOldFamily['$domain/$old'] ??= []).add(swap);
        }
        List<_SelectionSwap>? cycle(
          String start,
          String current,
          List<_SelectionSwap> path,
          Set<int> usedIndices,
          int limit,
          String domain,
        ) {
          if (path.length >= limit) {
            return null;
          }
          for (final next in cycleByOldFamily['$domain/$current'] ??
              const <_SelectionSwap>[]) {
            if (usedIndices.contains(next.index) ||
                path.any((swap) =>
                    swap.alternative.itemId == next.alternative.itemId)) {
              continue;
            }
            final following = [...path, next];
            if (next.alternative.familyId == start) {
              return following;
            }
            final found = cycle(
              start,
              next.alternative.familyId,
              following,
              {...usedIndices, next.index},
              limit,
              domain,
            );
            if (found != null) {
              return found;
            }
          }
          return null;
        }

        for (final first in swaps) {
          final domain = first.alternative.domain;
          final limit = selected.where((item) => item.domain == domain).length;
          final path = cycle(
            selected[first.index].familyId,
            first.alternative.familyId,
            [first],
            {first.index},
            limit,
            domain.name,
          );
          if (path == null) {
            continue;
          }
          for (final swap in path) {
            apply(swap);
          }
          break;
        }
      }
    }
  }
  return PracticeSelection(
    mode: mode,
    items: selected,
    buckets: buckets,
    repeatsPrecedingSet: selected.isNotEmpty && repeats(),
  );
}

final class _SelectionSwap {
  const _SelectionSwap(this.index, this.alternative);

  final int index;
  final SelectionCandidate alternative;
}

// Arithmetic stays below 2^53, so ranking agrees on Dart VM and Web.
int _rank(int seed, String id) {
  var value = seed % 2147483647;
  for (final unit in id.codeUnits) {
    value = (value * 31 + unit) % 2147483647;
  }
  return value;
}
