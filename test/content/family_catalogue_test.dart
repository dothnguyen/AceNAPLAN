import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

typedef _FamilySpec = ({
  String domain,
  String topic,
  String skill,
  String response,
  Map<String, int> variants,
});

const _expected = <String, _FamilySpec>{
  'N-PV-01': (
    domain: 'numeracy',
    topic: 'place_value',
    skill: 'Identify the value of a highlighted digit',
    response: 'numeric',
    variants: {'whole_number': 10, 'decimal': 10}
  ),
  'N-PV-02': (
    domain: 'numeracy',
    topic: 'place_value',
    skill: 'Compare or order number values',
    response: 'single_choice',
    variants: {'compare': 10, 'ordered_list': 10}
  ),
  'N-OP-01': (
    domain: 'numeracy',
    topic: 'operations_in_context',
    skill: 'Solve addition and subtraction word problems',
    response: 'numeric',
    variants: {'addition': 10, 'subtraction': 10}
  ),
  'N-OP-02': (
    domain: 'numeracy',
    topic: 'operations_in_context',
    skill: 'Solve equal grouping and sharing problems with whole answers',
    response: 'numeric',
    variants: {'equal_groups': 10, 'sharing_division': 10}
  ),
  'N-FD-01': (
    domain: 'numeracy',
    topic: 'fractions_and_decimals',
    skill: 'Find a fraction of a collection with an integral result',
    response: 'numeric',
    variants: {'described_set': 10, 'visually_grouped_set': 10}
  ),
  'N-FD-02': (
    domain: 'numeracy',
    topic: 'fractions_and_decimals',
    skill: 'Recognise equivalent fraction and decimal representations',
    response: 'single_choice',
    variants: {'equivalent_representations': 10, 'fraction_decimal_match': 10}
  ),
  'N-PA-01': (
    domain: 'numeracy',
    topic: 'patterns_and_unknowns',
    skill: 'Find an unknown value in a number sentence',
    response: 'numeric',
    variants: {'additive': 10, 'multiplicative': 10}
  ),
  'N-PA-02': (
    domain: 'numeracy',
    topic: 'patterns_and_unknowns',
    skill: 'Continue a sequence using its stated rule',
    response: 'numeric',
    variants: {'increasing': 10, 'decreasing': 10}
  ),
  'N-MT-01': (
    domain: 'numeracy',
    topic: 'measurement_and_time',
    skill: 'Calculate elapsed time without date rollover',
    response: 'numeric_with_displayed_unit',
    variants: {'within_hour': 10, 'crossing_hour': 10}
  ),
  'N-MT-02': (
    domain: 'numeracy',
    topic: 'measurement_and_time',
    skill: 'Read a scaled measuring instrument with labelled units',
    response: 'numeric_with_displayed_unit',
    variants: {'length': 10, 'capacity': 10}
  ),
  'N-SP-01': (
    domain: 'numeracy',
    topic: 'space',
    skill: 'Locate an object using a grid reference',
    response: 'single_choice',
    variants: {'identify_cell': 10, 'follow_location_instruction': 10}
  ),
  'N-SP-02': (
    domain: 'numeracy',
    topic: 'space',
    skill: 'Compare an angle with a right angle',
    response: 'single_choice',
    variants: {'smaller': 7, 'equal': 6, 'larger': 7}
  ),
  'N-DT-01': (
    domain: 'numeracy',
    topic: 'data_interpretation',
    skill: 'Read values from a scaled graph',
    response: 'numeric',
    variants: {'direct_value': 10, 'difference': 10}
  ),
  'N-DT-02': (
    domain: 'numeracy',
    topic: 'data_interpretation',
    skill: 'Compare values in a table',
    response: 'single_choice_or_numeric_per_item',
    variants: {'comparison': 10, 'difference': 10}
  ),
  'N-CH-01': (
    domain: 'numeracy',
    topic: 'chance',
    skill: 'Compare likelihoods from a simple collection',
    response: 'single_choice',
    variants: {'compare_events': 10, 'most_or_least_likely': 10}
  ),
  'N-CH-02': (
    domain: 'numeracy',
    topic: 'chance',
    skill: 'Identify possible, certain and impossible events',
    response: 'single_choice',
    variants: {'possible': 7, 'certain': 7, 'impossible': 6}
  ),
  'C-SP-01': (
    domain: 'conventions',
    topic: 'spelling',
    skill: 'Spell a word from contextual audio dictation',
    response: 'spelling_entry',
    variants: {'distinct_word_and_context_recording': 20}
  ),
  'C-SP-02': (
    domain: 'conventions',
    topic: 'spelling',
    skill: 'Correct a misspelled word in context',
    response: 'spelling_entry',
    variants: {'distinct_word_and_misspelling': 20}
  ),
  'C-GR-01': (
    domain: 'conventions',
    topic: 'grammar',
    skill: 'Choose subject–verb agreement in context',
    response: 'sentence_choice',
    variants: {'singular': 10, 'plural': 10}
  ),
  'C-GR-02': (
    domain: 'conventions',
    topic: 'grammar',
    skill: 'Complete a sentence with the appropriate tense, connective or word',
    response: 'sentence_choice',
    variants: {'tense': 8, 'connective': 6, 'appropriate_word': 6}
  ),
  'C-PU-01': (
    domain: 'conventions',
    topic: 'punctuation',
    skill: 'Choose sentence boundaries, end marks and capitals',
    response: 'sentence_choice',
    variants: {'end_mark_or_boundary': 10, 'capital_letter': 10}
  ),
  'C-PU-02': (
    domain: 'conventions',
    topic: 'punctuation',
    skill: 'Choose apostrophes for contractions or possession in context',
    response: 'sentence_choice',
    variants: {'contraction': 10, 'possession': 10}
  ),
};

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$label must be an object');
  }
  return value;
}

List<dynamic> _array(Object? value, String label) {
  if (value is! List<dynamic>) {
    throw FormatException('$label must be an array');
  }
  return value;
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

void _validate(Object? decoded) {
  final root = _object(decoded, 'catalogue');
  _require(root['schema_version'] == 1, 'Unsupported schema version');
  _require(root['status'] == 'draft_planning' && root['release_bank'] == false,
      'Catalogue must remain draft planning data');
  _require(
      root['planned_family_count'] == 22 && root['planned_item_count'] == 440,
      'Incorrect catalogue totals');

  final families = _array(root['families'], 'families');
  _require(families.length == 22, 'Expected 22 families');
  final seen = <String>{};
  var numeracy = 0;
  var conventions = 0;
  var totalItems = 0;
  for (final value in families) {
    final family = _object(value, 'family');
    final id = family['id'];
    _require(id is String && seen.add(id), 'Missing or duplicate family ID');
    final spec = _expected[id];
    _require(spec != null, 'Unknown family ID: $id');
    _require(
        family['domain'] == spec!.domain &&
            family['topic'] == spec.topic &&
            family['skill'] == spec.skill &&
            family['response_format'] == spec.response,
        'Unstable metadata for $id');
    _require(family['target_item_count'] == 20, 'Wrong family target for $id');
    final difficulty =
        _object(family['difficulty_targets'], '$id difficulties');
    _require(
        difficulty.length == 2 &&
            difficulty['introductory'] == 10 &&
            difficulty['developing'] == 10,
        'Wrong difficulty quotas for $id');
    final variants = _array(family['variants'], '$id variants');
    _require(
        variants.length == spec.variants.length, 'Wrong variant count for $id');
    final variantIds = <String>{};
    var variantTotal = 0;
    for (final value in variants) {
      final variant = _object(value, '$id variant');
      final variantId = variant['id'];
      _require(variantId is String && variantIds.add(variantId),
          'Missing or duplicate variant ID for $id');
      final count = variant['target_item_count'];
      _require(count is int && count > 0 && spec.variants[variantId] == count,
          'Wrong variant quota for $id/$variantId');
      variantTotal += count as int;
      if (id == 'N-DT-02') {
        _require(
            variant['response_format'] ==
                (variantId == 'comparison' ? 'single_choice' : 'numeric'),
            'Table item response format must be explicit');
      } else {
        _require(!variant.containsKey('response_format'),
            'Unexpected variant response format for $id');
      }
    }
    _require(variantTotal == 20, 'Variant total is not 20 for $id');
    if (spec.domain == 'numeracy') {
      numeracy++;
    } else {
      conventions++;
    }
    totalItems += 20;
  }
  _require(seen.containsAll(_expected.keys) && seen.length == _expected.length,
      'Approved family IDs are missing');
  _require(numeracy == 16 && conventions == 6 && totalItems == 440,
      'Domain or item totals are wrong');
}

void main() {
  final file = File('content/authoring/family_catalogue.json');

  test('approved offline family catalogue has stable metadata and quotas', () {
    _validate(jsonDecode(file.readAsStringSync()));
  });

  test('validator rejects malformed, missing, duplicate and changed data', () {
    final original =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    Map<String, dynamic> copy() =>
        jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    final mutations = <void Function(Map<String, dynamic>)>[
      (root) => root.remove('families'),
      (root) => (root['families'] as List).removeLast(),
      (root) => (root['families'] as List)[1]['id'] = 'N-PV-01',
      (root) => (root['families'] as List)[0]['id'] = 'N-PV-99',
      (root) => (root['families'] as List)[0]['skill'] = '',
      (root) => (root['families'] as List)[0]['topic'] = 'chance',
      (root) =>
          (root['families'] as List)[0]['difficulty_targets']['developing'] = 9,
      (root) =>
          (root['families'] as List)[0]['variants'][0]['target_item_count'] = 9,
      (root) =>
          (root['families'] as List)[0]['variants'][1]['id'] = 'whole_number',
      (root) => root['status'] = 'reviewed',
      (root) => root['planned_item_count'] = 420,
    ];
    for (final mutate in mutations) {
      final fixture = copy();
      mutate(fixture);
      expect(() => _validate(fixture), throwsFormatException);
    }
    expect(() => jsonDecode('{invalid json'), throwsFormatException);
  });
}
