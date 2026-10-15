import 'dart:typed_data';

/// Checks the structure of a little-endian, uncompressed PCM RIFF/WAVE file.
/// This does not establish that the recording is audible or correctly spoken.
bool isValidPcmWave(Uint8List bytes) {
  if (bytes.length < 44 ||
      !_fourCc(bytes, 0, 'RIFF') ||
      !_fourCc(bytes, 8, 'WAVE')) {
    return false;
  }
  final view = ByteData.sublistView(bytes);
  if (view.getUint32(4, Endian.little) + 8 != bytes.length) return false;

  var offset = 12;
  var blockAlign = 0;
  var foundFormat = false;
  var foundData = false;
  while (offset < bytes.length) {
    if (bytes.length - offset < 8) return false;
    final length = view.getUint32(offset + 4, Endian.little);
    final dataStart = offset + 8;
    final end = dataStart + length;
    final paddedEnd = end + (length.isOdd ? 1 : 0);
    if (paddedEnd > bytes.length) return false;

    if (_fourCc(bytes, offset, 'fmt ')) {
      if (foundFormat || length < 16) return false;
      final formatTag = view.getUint16(dataStart, Endian.little);
      final channels = view.getUint16(dataStart + 2, Endian.little);
      final sampleRate = view.getUint32(dataStart + 4, Endian.little);
      final byteRate = view.getUint32(dataStart + 8, Endian.little);
      blockAlign = view.getUint16(dataStart + 12, Endian.little);
      final bitDepth = view.getUint16(dataStart + 14, Endian.little);
      if (formatTag != 1 ||
          channels == 0 ||
          sampleRate == 0 ||
          bitDepth == 0 ||
          bitDepth.isOdd ||
          bitDepth % 8 != 0 ||
          blockAlign != channels * (bitDepth ~/ 8) ||
          byteRate != sampleRate * blockAlign) {
        return false;
      }
      if (length != 16) {
        if (length < 18 ||
            view.getUint16(dataStart + 16, Endian.little) != length - 18) {
          return false;
        }
      }
      foundFormat = true;
    } else if (_fourCc(bytes, offset, 'data')) {
      if (foundData ||
          !foundFormat ||
          length == 0 ||
          length % blockAlign != 0) {
        return false;
      }
      foundData = true;
    }
    offset = paddedEnd;
  }
  return foundFormat && foundData;
}

bool _fourCc(Uint8List bytes, int offset, String text) {
  for (var i = 0; i < 4; i++) {
    if (bytes[offset + i] != text.codeUnitAt(i)) return false;
  }
  return true;
}

final _word = RegExp(r"[A-Za-z]+(?:['’\-][A-Za-z]+)*");
final _target = RegExp(r"^[A-Za-z]+(?:['’\-][A-Za-z]+)*$");

/// Checks the reviewed script's word–sentence–word structure, not the audio.
/// Sentence punctuation makes the three spoken parts unambiguous to reviewers.
bool isValidDictationTranscript({
  required String transcript,
  required String targetWord,
}) {
  final target = targetWord.trim().toLowerCase();
  if (!_target.hasMatch(target)) return false;
  final parts = transcript.trim().split(RegExp(r'[.!?]+'));
  if (parts.isNotEmpty && parts.last.trim().isEmpty) parts.removeLast();
  if (parts.length != 3) return false;
  if (parts.first.trim().toLowerCase() != target ||
      parts.last.trim().toLowerCase() != target) {
    return false;
  }
  final sentence = parts[1].trim();
  final words = _word
      .allMatches(sentence)
      .map((match) => match.group(0)!.toLowerCase())
      .toList();
  if (words.length < 4 ||
      words.where((word) => word != target).length < 3 ||
      !words.contains(target)) {
    return false;
  }
  // Reject symbols or fragments that our word tokenizer cannot account for.
  final prose =
      sentence.replaceAll(_word, '').replaceAll(RegExp(r"[\s,;:'’\-]"), '');
  return prose.isEmpty;
}
