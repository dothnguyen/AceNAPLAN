import 'dart:convert';

import '../../domain/answer_rule.dart';
import '../../domain/question.dart';

/// Wire format for draft, prevalidated content. A review ID is a reference,
/// never evidence that an educator approved this record for release.
final class ContentBundleCodec {
  const ContentBundleCodec();

  static const int schemaVersion = 1;

  String encodeQuestion(QuestionRevision question) {
    if (question.contentSchemaVersion != schemaVersion) {
      throw const FormatException('Unsupported content schema.');
    }
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'itemId': question.itemId,
      'variantId': question.variantId,
      'familyId': question.familyId,
      'revision': question.revision,
      'contentSchemaVersion': question.contentSchemaVersion,
      'bankVersion': question.bankVersion,
      'topic': question.topic,
      'domain': question.domain.name,
      'difficulty': question.difficulty.name,
      'curriculumReferences': question.curriculumReferences,
      'skillReferences': question.skillReferences,
      'provenance': question.provenance,
      'license': question.license,
      'contentDigest': question.contentDigest,
      'reviewRecordId': question.reviewRecordId,
      'prompt': question.prompt,
      'stimulusDescription': question.stimulusDescription,
      'hint': question.hint,
      'explanation': question.explanation,
      'assets': question.assets.map(_assetMap).toList(),
      'answerRule': _ruleMap(question.answerRule),
    });
  }

  QuestionRevision decodeQuestion(String source) {
    final map = _parse(source);
    _fields(map, const {
      'schemaVersion',
      'itemId',
      'variantId',
      'familyId',
      'revision',
      'contentSchemaVersion',
      'bankVersion',
      'topic',
      'domain',
      'difficulty',
      'curriculumReferences',
      'skillReferences',
      'provenance',
      'license',
      'contentDigest',
      'reviewRecordId',
      'prompt',
      'stimulusDescription',
      'hint',
      'explanation',
      'assets',
      'answerRule',
    });
    _version(map);
    if (_integer(map, 'contentSchemaVersion') != schemaVersion) {
      throw const FormatException('Unsupported content schema.');
    }
    try {
      return QuestionRevision(
        itemId: _string(map, 'itemId'),
        variantId: _string(map, 'variantId'),
        familyId: _string(map, 'familyId'),
        revision: _integer(map, 'revision'),
        contentSchemaVersion: schemaVersion,
        bankVersion: _string(map, 'bankVersion'),
        topic: _string(map, 'topic'),
        domain: _enumValue(QuestionDomain.values, _string(map, 'domain')),
        difficulty:
            _enumValue(QuestionDifficulty.values, _string(map, 'difficulty')),
        curriculumReferences: _strings(map, 'curriculumReferences'),
        skillReferences: _strings(map, 'skillReferences'),
        provenance: _string(map, 'provenance'),
        license: _string(map, 'license'),
        contentDigest: _string(map, 'contentDigest'),
        reviewRecordId: _string(map, 'reviewRecordId'),
        prompt: _string(map, 'prompt'),
        stimulusDescription: _string(map, 'stimulusDescription'),
        hint: _string(map, 'hint'),
        explanation: _string(map, 'explanation'),
        assets: _assets(map['assets']),
        answerRule: _decodeRule(map['answerRule']),
      );
    } on ArgumentError {
      throw const FormatException('Invalid content record.');
    }
  }

  String encodeAnswerRule(AnswerRule rule) => jsonEncode(_ruleMap(rule));

  AnswerRule decodeAnswerRule(String source) => _decodeRule(_parse(source));

  String encodeAssets(List<QuestionAsset> assets) =>
      jsonEncode(assets.map(_assetMap).toList());

  List<QuestionAsset> decodeAssets(String source) {
    try {
      return _assets(jsonDecode(source));
    } on FormatException {
      throw const FormatException('Invalid assets JSON.');
    }
  }
}

Map<String, Object?> _assetMap(QuestionAsset asset) => {
      'id': asset.id,
      'digest': asset.digest,
      'description': asset.description,
    };

Map<String, Object?> _ruleMap(AnswerRule rule) {
  final common = <String, Object?>{
    'schemaVersion': ContentBundleCodec.schemaVersion,
    'scoringPolicyVersion': rule.scoringPolicyVersion,
  };
  if (rule is SingleChoiceRule || rule is SentenceChoiceRule) {
    final options = rule is SingleChoiceRule
        ? rule.options
        : (rule as SentenceChoiceRule).options;
    final correct = rule is SingleChoiceRule
        ? rule.correctOptionId
        : (rule as SentenceChoiceRule).correctOptionId;
    return {
      ...common,
      'type': rule is SingleChoiceRule ? 'singleChoice' : 'sentenceChoice',
      'options': options.map((o) => {'id': o.id, 'label': o.label}).toList(),
      'correctOptionId': correct,
    };
  }
  if (rule is NumericRule) {
    return {
      ...common,
      'type': 'numeric',
      'correctValue': rule.correctValue.canonical,
      'displayedUnit': rule.displayedUnit,
    };
  }
  if (rule is SpellingRule) {
    return {
      ...common,
      'type': 'spelling',
      'target': rule.target,
      'alternatives': rule.alternatives,
    };
  }
  throw const FormatException('Unsupported answer rule.');
}

AnswerRule _decodeRule(Object? raw) {
  final map = _object(raw);
  _version(map);
  final type = _string(map, 'type');
  final policy = _integer(map, 'scoringPolicyVersion');
  try {
    switch (type) {
      case 'singleChoice':
      case 'sentenceChoice':
        _fields(map, const {
          'schemaVersion',
          'scoringPolicyVersion',
          'type',
          'options',
          'correctOptionId',
        });
        final rawOptions = map['options'];
        if (rawOptions is! List) {
          throw const FormatException('Invalid options.');
        }
        final options = rawOptions.map((raw) {
          final option = _object(raw);
          _fields(option, const {'id', 'label'});
          return ChoiceOption(
              id: _string(option, 'id'), label: _string(option, 'label'));
        }).toList();
        final correct = _string(map, 'correctOptionId');
        return type == 'singleChoice'
            ? SingleChoiceRule(
                options: options,
                correctOptionId: correct,
                scoringPolicyVersion: policy)
            : SentenceChoiceRule(
                options: options,
                correctOptionId: correct,
                scoringPolicyVersion: policy);
      case 'numeric':
        _fields(map, const {
          'schemaVersion',
          'scoringPolicyVersion',
          'type',
          'correctValue',
          'displayedUnit',
        });
        final unit = map['displayedUnit'];
        if (unit != null && unit is! String) {
          throw const FormatException('Invalid unit.');
        }
        return NumericRule(
            correctValue: _string(map, 'correctValue'),
            displayedUnit: unit as String?,
            scoringPolicyVersion: policy);
      case 'spelling':
        _fields(map, const {
          'schemaVersion',
          'scoringPolicyVersion',
          'type',
          'target',
          'alternatives',
        });
        return SpellingRule(
            target: _string(map, 'target'),
            alternatives: _strings(map, 'alternatives'),
            scoringPolicyVersion: policy);
      default:
        throw const FormatException('Unsupported answer rule.');
    }
  } on ArgumentError {
    throw const FormatException('Invalid answer rule.');
  }
}

List<QuestionAsset> _assets(Object? raw) {
  if (raw is! List) throw const FormatException('Invalid assets.');
  try {
    return raw.map((value) {
      final map = _object(value);
      _fields(map, const {'id', 'digest', 'description'});
      return QuestionAsset(
          id: _string(map, 'id'),
          digest: _string(map, 'digest'),
          description: _string(map, 'description'));
    }).toList();
  } on ArgumentError {
    throw const FormatException('Invalid assets.');
  }
}

Map<String, Object?> _parse(String source) {
  try {
    return _object(jsonDecode(source));
  } on FormatException {
    throw const FormatException('Invalid content JSON.');
  }
}

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Expected object.');
  }
  return raw;
}

void _fields(Map<String, Object?> map, Set<String> expected) {
  if (map.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(map.keys.toSet()).isNotEmpty) {
    throw const FormatException('Invalid content fields.');
  }
}

void _version(Map<String, Object?> map) {
  if (_integer(map, 'schemaVersion') != ContentBundleCodec.schemaVersion) {
    throw const FormatException('Unsupported content schema.');
  }
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid content field.');
  }
  return value;
}

int _integer(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int || value < 1) {
    throw const FormatException('Invalid content version.');
  }
  return value;
}

List<String> _strings(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw is! List || raw.any((value) => value is! String)) {
    throw const FormatException('Invalid content list.');
  }
  return raw.cast<String>();
}

T _enumValue<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw const FormatException('Unsupported content tag.');
}
