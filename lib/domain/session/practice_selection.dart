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
    if (reservedItemIds.contains(candidate.itemId)) return false;
    if (exposedItemIds.contains(candidate.itemId) !=
        (mode == PracticeMode.review)) return false;
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
          if (old.domain != domain) continue;
          for (final replacement in byKey[keyOf(old)]!) {
            if (replacement.familyId == old.familyId) continue;
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
    for (final key in keys) {
      for (final alternative in byKey[key]!) {
        if (precedingItemIds.contains(alternative.itemId)) continue;
        final indices = <int>[
          for (var i = 0; i < selected.length; i++)
            if (keyOf(selected[i]) == key) i,
        ];
        // Preserve the family mix if an exchange within the family exists.
        indices.sort((a, b) {
          final aMatch = selected[a].familyId == alternative.familyId ? 0 : 1;
          final bMatch = selected[b].familyId == alternative.familyId ? 0 : 1;
          return aMatch.compareTo(bMatch);
        });
        for (final index in indices) {
          if (!topicMode && selected[index].familyId != alternative.familyId) {
            final counts = <String, int>{};
            final families = eligible
                .where((item) => item.domain == alternative.domain)
                .map((item) => item.familyId)
                .toSet();
            for (final family in families) {
              counts[family] = 0;
            }
            for (var i = 0; i < selected.length; i++) {
              if (i == index || selected[i].domain != alternative.domain)
                continue;
              counts[selected[i].familyId] =
                  (counts[selected[i].familyId] ?? 0) + 1;
            }
            counts[alternative.familyId] =
                (counts[alternative.familyId] ?? 0) + 1;
            final values = counts.values.toList();
            if (values.reduce((a, b) => a > b ? a : b) -
                    values.reduce((a, b) => a < b ? a : b) >
                1) {
              continue;
            }
          }
          selectedIds.remove(selected[index].itemId);
          selected[index] = alternative;
          selectedIds.add(alternative.itemId);
          break;
        }
        if (!repeats()) break;
      }
      if (!repeats()) break;
    }
  }
  return PracticeSelection(
    mode: mode,
    items: selected,
    buckets: buckets,
    repeatsPrecedingSet: selected.isNotEmpty && repeats(),
  );
}

// Arithmetic stays below 2^53, so ranking agrees on Dart VM and Web.
int _rank(int seed, String id) {
  var value = seed % 2147483647;
  for (final unit in id.codeUnits) {
    value = (value * 31 + unit) % 2147483647;
  }
  return value;
}
