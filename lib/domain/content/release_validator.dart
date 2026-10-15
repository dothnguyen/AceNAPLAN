import 'dart:typed_data';

import '../answer_rule.dart';
import '../question.dart';
import 'bank_quota_validator.dart';
import 'audio_validation.dart';
import 'canonical_question_digest.dart';

export 'canonical_question_digest.dart' show sha256Hex;

/// Inputs must come from the exact asset bytes staged for the release bundle.
/// Locally editable review records are evidence to inspect, not authentication
/// of an educator's identity or sign-off.
List<String> validateReleaseContent({
  required List<QuestionRevision> items,
  required Map<String, dynamic> catalogue,
  required Map<String, Uint8List> bundledBytes,
  required Map<String, dynamic> assetManifest,
  required Map<String, dynamic> itemReviews,
  required Map<String, dynamic> audioReviews,
  required Map<String, dynamic> dictationAlternatives,
  required Map<String, Map<String, String>> variationValues,
}) {
  final issues = validateBankQuotas(items: items, catalogue: catalogue);
  if (catalogue['release_bank'] != true ||
      catalogue['status'] != 'release_approved') {
    issues.add('Catalogue is draft or not release approved');
  }
  final referencedPaths = <String>{};
  final seenAssetIds = <String>{};
  final itemsById = {for (final item in items) item.itemId: item};
  for (final item in items) {
    final label = '${item.itemId}@${item.revision}';
    final itemReview = itemReviews[item.reviewRecordId];
    final computedDigest = canonicalQuestionDigest(item);
    if (!_digestPattern.hasMatch(item.contentDigest) ||
        item.contentDigest != computedDigest ||
        !_approvedReview(itemReview, item.itemId, computedDigest) ||
        itemReview is! Map ||
        itemReview['revision'] != item.revision) {
      issues.add(
          'Missing or unreviewed item record or content digest mismatch for $label');
    }
    for (final asset in item.assets) {
      if (!seenAssetIds.add(asset.id)) {
        issues.add('Duplicate asset ID ${asset.id}');
      }
      final raw = assetManifest[asset.id];
      if (raw is! Map || raw['path'] is! String) {
        issues.add('Missing asset path for ${asset.id}');
        continue;
      }
      final path = raw['path'] as String;
      if (!_safePath(path)) {
        issues.add('Unsafe asset path for ${asset.id}');
        continue;
      }
      referencedPaths.add(path);
      final bytes = bundledBytes[path];
      if (bytes == null || bytes.isEmpty) {
        issues.add('Missing asset bytes for ${asset.id}');
        continue;
      }
      if (!_digestPattern.hasMatch(asset.digest) ||
          sha256Hex(bytes) != asset.digest.toLowerCase() ||
          raw['digest'] != asset.digest) {
        issues.add('Asset digest mismatch for ${asset.id}');
      }
      if (raw['kind'] == 'audio') {
        if (!isValidPcmWave(bytes)) {
          issues.add('Malformed audio for ${asset.id}');
        }
        final audioReview = audioReviews[asset.id];
        if (!_approvedReview(audioReview, asset.id, asset.digest) ||
            audioReview is! Map ||
            audioReview['item_id'] != item.itemId ||
            !_nonblank(audioReview['transcript']) ||
            !_nonblank(audioReview['provenance']) ||
            !_nonblank(audioReview['rights'])) {
          issues.add('Missing or unreviewed audio record for ${asset.id}');
        }
      } else if (raw['kind'] != 'visual') {
        issues.add('Unknown asset kind for ${asset.id}');
      }
    }
    if (item.familyId == 'C-SP-01') {
      final audio = item.assets.where((asset) {
        final entry = assetManifest[asset.id];
        return entry is Map && entry['kind'] == 'audio';
      });
      if (audio.length != 1) {
        issues.add('Dictation requires one recording for $label');
      } else {
        final review = audioReviews[audio.single.id];
        final target = item.answerRule;
        if (target is! SpellingRule ||
            review is! Map ||
            review['target_word'] is! String ||
            (review['target_word'] as String).trim().toLowerCase() !=
                target.target.trim().toLowerCase() ||
            review['transcript'] is! String ||
            !isValidDictationTranscript(
              transcript: review['transcript'] as String,
              targetWord: target.target,
            )) {
          issues.add('Dictation transcript or target mismatch for $label');
        }
      }
      final alternativeId = dictationAlternatives[item.itemId];
      final alternative = itemsById[alternativeId];
      if (alternative == null ||
          alternative.familyId != 'C-SP-02' ||
          alternative.itemId == item.itemId ||
          alternative.answerRule is! SpellingRule ||
          !_nonblank(alternative.stimulusDescription) ||
          alternative.assets.any((asset) {
            final entry = assetManifest[asset.id];
            return entry is Map && entry['kind'] == 'audio';
          })) {
        issues.add('Missing accessible correction alternative for $label');
      }
    }
  }
  for (final path in bundledBytes.keys.toSet().difference(referencedPaths)) {
    issues.add('Unreferenced bundled asset $path');
  }
  for (final id in assetManifest.keys.toSet().difference(seenAssetIds)) {
    issues.add('Unreferenced asset manifest entry $id');
  }
  for (final id in audioReviews.keys.toSet().difference(seenAssetIds)) {
    issues.add('Unreferenced audio review $id');
  }
  for (final id in itemReviews.keys
      .toSet()
      .difference(items.map((item) => item.reviewRecordId).toSet())) {
    issues.add('Unreferenced item review $id');
  }
  for (final id in dictationAlternatives.keys.toSet().difference(items
      .where((item) => item.familyId == 'C-SP-01')
      .map((item) => item.itemId)
      .toSet())) {
    issues.add('Unexpected dictation alternative mapping $id');
  }
  final rawFamilies = catalogue['families'];
  if (rawFamilies is List) {
    for (final rawFamily in rawFamilies) {
      if (rawFamily is! Map) continue;
      final familyId = rawFamily['id'];
      if (familyId is! String) continue;
      final fields = rawFamily['variation_fields'];
      if (fields is! List ||
          fields.isEmpty ||
          fields.any((field) =>
              field is! String || !_substantiveFields.contains(field)) ||
          fields.toSet().length != fields.length) {
        issues.add('Missing substantive variation fields for $familyId');
        continue;
      }
      final signatures = <String>{};
      final distinct = {for (final field in fields) field: <String>{}};
      for (final item in items.where((item) => item.familyId == familyId)) {
        final values = variationValues[item.itemId];
        if (values == null ||
            values.keys.toSet().difference(fields.toSet()).isNotEmpty ||
            fields.any((field) => !_nonblank(values[field]))) {
          issues.add('Missing declared variation for ${item.itemId}');
          continue;
        }
        final bound = <String, String>{};
        for (final field in fields) {
          final actual = _boundVariation(item, field,
              assetManifest: assetManifest,
              bundledBytes: bundledBytes,
              audioReviews: audioReviews);
          if (actual == null) {
            issues.add('Unsupported variation binding for $familyId.$field');
          } else if (_normalizeVariation(values[field]!) != actual) {
            issues.add(
                'Declared $field does not match content for ${item.itemId}');
          } else {
            bound[field] = actual;
          }
        }
        if (bound.length != fields.length) continue;
        final signature = fields.map((field) => bound[field]!).join('\u001f');
        if (!signatures.add(signature)) {
          issues.add('Trivially repeated variation in $familyId');
        }
        for (final field in fields) {
          distinct[field]!.add(bound[field]!);
        }
      }
      if (distinct.values.any((values) => values.length < 2)) {
        issues.add('Insufficient declared variation in $familyId');
      }
    }
  }
  for (final id
      in variationValues.keys.toSet().difference(itemsById.keys.toSet())) {
    issues.add('Variation for unknown item $id');
  }
  return issues;
}

const _substantiveFields = {
  'values',
  'relationship',
  'representation',
  'context',
  'target_word',
  'sentence_structure',
  'misconception',
  'scale',
  'unit',
  'operation',
};
final _digestPattern = RegExp(r'^[a-fA-F0-9]{64}$');

String _normalizeVariation(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Only exact, family-specific bindings count. A word appearing somewhere in a
/// prompt cannot prove an operation, relationship, scale or visual meaning.
String? _boundVariation(QuestionRevision item, String field,
    {required Map<String, dynamic> assetManifest,
    required Map<String, Uint8List> bundledBytes,
    required Map<String, dynamic> audioReviews}) {
  if (item.familyId != 'C-SP-01' && item.familyId != 'C-SP-02') {
    return null;
  }
  if (field == 'target_word') {
    final rule = item.answerRule;
    if (rule is! SpellingRule) return null;
    return _normalizeVariation(rule.target);
  }
  if (field != 'context') return null;
  if (item.familyId == 'C-SP-02') {
    // The correction task displays this sentence as its stimulus.
    return _normalizeVariation(item.stimulusDescription);
  }
  final audio = item.assets.where((asset) {
    final entry = assetManifest[asset.id];
    return entry is Map && entry['kind'] == 'audio';
  }).toList();
  if (audio.length != 1) return null;
  final entry = assetManifest[audio.single.id];
  if (entry is! Map || entry['path'] is! String) return null;
  final path = entry['path'] as String;
  final bytes = bundledBytes[path];
  if (!_safePath(path) ||
      bytes == null ||
      !isValidPcmWave(bytes) ||
      !_digestPattern.hasMatch(audio.single.digest) ||
      entry['digest'] != audio.single.digest ||
      sha256Hex(bytes) != audio.single.digest.toLowerCase()) {
    return null;
  }
  final review = audioReviews[audio.single.id];
  if (review is! Map ||
      review['item_id'] != item.itemId ||
      !_approvedReview(review, audio.single.id, audio.single.digest) ||
      !_nonblank(review['transcript'])) {
    return null;
  }
  // The transcript is reviewed against the digest-checked recording above.
  // It is an exact transcript binding, not automated speech verification.
  return _normalizeVariation(review['transcript'] as String);
}

bool _nonblank(Object? value) => value is String && value.trim().isNotEmpty;

bool _approvedReview(Object? raw, String id, String digest) =>
    raw is Map &&
    raw['id'] == id &&
    raw['digest'] == digest &&
    raw['status'] == 'approved' &&
    _nonblank(raw['reviewer']) &&
    _nonblank(raw['reviewed_at']);

bool _safePath(String path) =>
    path.startsWith('assets/') &&
    !path.contains('\\') &&
    !path.contains('//') &&
    !path.contains(':') &&
    path
        .split('/')
        .every((part) => part.isNotEmpty && part != '.' && part != '..');
