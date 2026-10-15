import 'dart:convert';
import 'dart:typed_data';

import '../answer_rule.dart';
import '../question.dart';

/// Version 1 canonical bytes: UTF-8 JSON with fixed key and list order.
/// A changed projection requires a new version and new educator review.
Uint8List canonicalQuestionBytes(QuestionRevision question) =>
    Uint8List.fromList(utf8.encode(jsonEncode(_projection(question))));

String canonicalQuestionDigest(QuestionRevision question) =>
    sha256Hex(canonicalQuestionBytes(question));

Map<String, Object?> _projection(QuestionRevision question) => {
      'digestVersion': 1,
      'itemId': question.itemId,
      'variantId': question.variantId,
      'familyId': question.familyId,
      'revision': question.revision,
      'contentSchemaVersion': question.contentSchemaVersion,
      'topic': question.topic,
      'domain': question.domain.name,
      'difficulty': question.difficulty.name,
      'curriculumReferences': question.curriculumReferences,
      'skillReferences': question.skillReferences,
      'provenance': question.provenance,
      'license': question.license,
      'prompt': question.prompt,
      'stimulusDescription': question.stimulusDescription,
      'hint': question.hint,
      'explanation': question.explanation,
      'assets': [
        for (final asset in question.assets)
          {
            'id': asset.id,
            'digest': asset.digest,
            'description': asset.description,
          }
      ],
      'answerRule': _answerRule(question.answerRule),
    };

Map<String, Object?> _answerRule(AnswerRule rule) {
  final common = <String, Object?>{
    'schemaVersion': 1,
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
      'options': [
        for (final option in options) {'id': option.id, 'label': option.label}
      ],
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

/// Small dependency-free SHA-256 for release bytes; not used in render loops.
String sha256Hex(Uint8List input) {
  final data = Uint8List(((input.length + 9 + 63) ~/ 64) * 64);
  data.setRange(0, input.length, input);
  data[input.length] = 0x80;
  final bits = input.length * 8;
  final view = ByteData.sublistView(data);
  view.setUint32(data.length - 8, (bits ~/ 0x100000000) & 0xffffffff);
  view.setUint32(data.length - 4, bits & 0xffffffff);
  final h = List<int>.from(_initial);
  final w = List<int>.filled(64, 0);
  for (var offset = 0; offset < data.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = view.getUint32(offset + i * 4);
    }
    for (var i = 16; i < 64; i++) {
      w[i] = (_sigma1(w[i - 2]) + w[i - 7] + _sigma0(w[i - 15]) + w[i - 16]) &
          0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], z = h[7];
    for (var i = 0; i < 64; i++) {
      final t1 = (z + _big1(e) + ((e & f) ^ ((~e) & g)) + _round[i] + w[i]) &
          0xffffffff;
      final t2 = (_big0(a) + ((a & b) ^ (a & c) ^ (b & c))) & 0xffffffff;
      z = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    final round = [a, b, c, d, e, f, g, z];
    for (var i = 0; i < 8; i++) {
      h[i] = (h[i] + round[i]) & 0xffffffff;
    }
  }
  return h.map((part) => part.toRadixString(16).padLeft(8, '0')).join();
}

int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
int _sigma0(int x) => _rotr(x, 7) ^ _rotr(x, 18) ^ (x >>> 3);
int _sigma1(int x) => _rotr(x, 17) ^ _rotr(x, 19) ^ (x >>> 10);
int _big0(int x) => _rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22);
int _big1(int x) => _rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25);
const _initial = [
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19
];
const _round = [
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];
