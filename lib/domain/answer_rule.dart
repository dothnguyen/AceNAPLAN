/// Pure, deterministic answer validation for pilot question formats.
library;

sealed class AnswerResponse {
  const AnswerResponse();
}

final class ChoiceResponse extends AnswerResponse {
  const ChoiceResponse(this.optionId);
  final String optionId;
}

final class TextResponse extends AnswerResponse {
  const TextResponse(this.text);
  final String text;
}

enum InvalidAnswerReason { wrongFormat, blank, tooLong, unknownOption, syntax }

sealed class AnswerResult {
  const AnswerResult();
}

final class InvalidAnswer extends AnswerResult {
  const InvalidAnswer(this.reason);
  final InvalidAnswerReason reason;
}

final class ScoredAnswer extends AnswerResult {
  const ScoredAnswer({
    required this.normalizedResponse,
    required this.isCorrect,
    required this.scoringPolicyVersion,
  });

  final String normalizedResponse;
  final bool isCorrect;
  final int scoringPolicyVersion;
}

sealed class AnswerRule {
  const AnswerRule(this.scoringPolicyVersion);
  final int scoringPolicyVersion;

  AnswerResult score(AnswerResponse response);
}

final class ChoiceOption {
  ChoiceOption({required this.id, required this.label}) {
    _requireText(id, 'option id');
    if (id.length > 128) {
      throw ArgumentError('Option ID exceeds 128 code units.');
    }
    _requireText(label, 'option label');
  }

  final String id;
  final String label;
}

abstract class _ChoiceRule extends AnswerRule {
  _ChoiceRule({
    required List<ChoiceOption> options,
    required this.correctOptionId,
    required int scoringPolicyVersion,
  })  : options = List.unmodifiable(options),
        super(scoringPolicyVersion) {
    _requirePositive(scoringPolicyVersion, 'scoring policy version');
    if (this.options.length < 2) {
      throw ArgumentError('At least two options are required.');
    }
    final ids = this.options.map((option) => option.id).toSet();
    if (ids.length != this.options.length || !ids.contains(correctOptionId)) {
      throw ArgumentError('Options must have unique IDs and one keyed answer.');
    }
  }

  final List<ChoiceOption> options;
  final String correctOptionId;

  @override
  AnswerResult score(AnswerResponse response) {
    if (response is! ChoiceResponse) {
      return const InvalidAnswer(InvalidAnswerReason.wrongFormat);
    }
    if (response.optionId.length > 128) {
      return const InvalidAnswer(InvalidAnswerReason.tooLong);
    }
    if (response.optionId.trim().isEmpty) {
      return const InvalidAnswer(InvalidAnswerReason.blank);
    }
    if (!options.any((option) => option.id == response.optionId)) {
      return const InvalidAnswer(InvalidAnswerReason.unknownOption);
    }
    return ScoredAnswer(
      normalizedResponse: response.optionId,
      isCorrect: response.optionId == correctOptionId,
      scoringPolicyVersion: scoringPolicyVersion,
    );
  }
}

final class SingleChoiceRule extends _ChoiceRule {
  SingleChoiceRule({
    required super.options,
    required super.correctOptionId,
    required super.scoringPolicyVersion,
  });
}

final class SentenceChoiceRule extends _ChoiceRule {
  SentenceChoiceRule({
    required super.options,
    required super.correctOptionId,
    required super.scoringPolicyVersion,
  });
}

/// Exact base-10 value. Input is bounded before parsing to avoid huge integers.
final class ExactDecimal {
  const ExactDecimal._(this.coefficient, this.scale);

  static const maxRawLength = 128;
  static const maxDigits = 64;
  static const maxFractionalDigits = 32;
  static final _syntax = RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$');

  final BigInt coefficient;
  final int scale;

  static ExactDecimal? parse(String raw) {
    if (raw.length > maxRawLength) return null;
    final value = raw.trim();
    if (!_syntax.hasMatch(value)) return null;
    var unsigned = value;
    var negative = false;
    if (unsigned.startsWith('-') || unsigned.startsWith('+')) {
      negative = unsigned.startsWith('-');
      unsigned = unsigned.substring(1);
    }
    final dot = unsigned.indexOf('.');
    final whole = dot == -1 ? unsigned : unsigned.substring(0, dot);
    final fraction = dot == -1 ? '' : unsigned.substring(dot + 1);
    if (whole.length + fraction.length > maxDigits ||
        fraction.length > maxFractionalDigits) {
      return null;
    }
    var coefficient = BigInt.parse('$whole$fraction');
    if (negative) coefficient = -coefficient;
    var scale = fraction.length;
    if (coefficient == BigInt.zero) return ExactDecimal._(BigInt.zero, 0);
    while (scale > 0 && coefficient.remainder(BigInt.from(10)) == BigInt.zero) {
      coefficient = coefficient ~/ BigInt.from(10);
      scale--;
    }
    return ExactDecimal._(coefficient, scale);
  }

  String get canonical {
    if (scale == 0) return coefficient.toString();
    final digits = coefficient.abs().toString().padLeft(scale + 1, '0');
    final point = digits.length - scale;
    return '${coefficient.isNegative ? '-' : ''}${digits.substring(0, point)}.${digits.substring(point)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ExactDecimal &&
      coefficient == other.coefficient &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(coefficient, scale);
}

final class NumericRule extends AnswerRule {
  NumericRule({
    required String correctValue,
    required int scoringPolicyVersion,
    this.displayedUnit,
  })  : correctValue = ExactDecimal.parse(correctValue) ??
            (throw ArgumentError.value(
                correctValue, 'correctValue', 'Invalid decimal')),
        super(scoringPolicyVersion) {
    _requirePositive(scoringPolicyVersion, 'scoring policy version');
    if (displayedUnit != null) _requireText(displayedUnit!, 'displayed unit');
  }

  final ExactDecimal correctValue;

  /// This label is displayed beside the field. Input never includes a unit.
  final String? displayedUnit;

  @override
  AnswerResult score(AnswerResponse response) {
    if (response is! TextResponse) {
      return const InvalidAnswer(InvalidAnswerReason.wrongFormat);
    }
    if (response.text.length > ExactDecimal.maxRawLength) {
      return const InvalidAnswer(InvalidAnswerReason.tooLong);
    }
    if (response.text.trim().isEmpty) {
      return const InvalidAnswer(InvalidAnswerReason.blank);
    }
    final parsed = ExactDecimal.parse(response.text);
    if (parsed == null) {
      return const InvalidAnswer(InvalidAnswerReason.syntax);
    }
    return ScoredAnswer(
      normalizedResponse: parsed.canonical,
      isCorrect: parsed == correctValue,
      scoringPolicyVersion: scoringPolicyVersion,
    );
  }
}

final class SpellingRule extends AnswerRule {
  SpellingRule({
    required String target,
    List<String> alternatives = const [],
    required int scoringPolicyVersion,
  })  : target = _normalizeSpellingKey(target),
        alternatives =
            List.unmodifiable(alternatives.map(_normalizeSpellingKey)),
        super(scoringPolicyVersion) {
    _requirePositive(scoringPolicyVersion, 'scoring policy version');
    if ({this.target, ...this.alternatives}.length !=
        this.alternatives.length + 1) {
      throw ArgumentError('Spelling keys must be unique after normalization.');
    }
  }

  static const maxRawLength = 128;
  final String target;
  final List<String> alternatives;

  @override
  AnswerResult score(AnswerResponse response) {
    if (response is! TextResponse) {
      return const InvalidAnswer(InvalidAnswerReason.wrongFormat);
    }
    if (response.text.length > maxRawLength) {
      return const InvalidAnswer(InvalidAnswerReason.tooLong);
    }
    final normalized = response.text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const InvalidAnswer(InvalidAnswerReason.blank);
    }
    return ScoredAnswer(
      normalizedResponse: normalized,
      isCorrect: normalized == target || alternatives.contains(normalized),
      scoringPolicyVersion: scoringPolicyVersion,
    );
  }
}

String _normalizeSpellingKey(String key) {
  if (key.length > SpellingRule.maxRawLength || key.trim().isEmpty) {
    throw ArgumentError.value(key, 'key', 'Blank or oversized spelling key');
  }
  return key.trim().toLowerCase();
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError.value(value, name, 'Required');
}

void _requirePositive(int value, String name) {
  if (value < 1) throw ArgumentError.value(value, name, 'Must be positive');
}
