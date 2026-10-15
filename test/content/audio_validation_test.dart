import 'dart:convert';
import 'dart:typed_data';

import 'package:ace_naplan5/domain/content/audio_validation.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List wave({
  int channels = 1,
  int sampleRate = 8000,
  int bitDepth = 16,
  int dataLength = 4,
}) {
  final length = 44 + dataLength + (dataLength.isOdd ? 1 : 0);
  final bytes = Uint8List(length);
  final view = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  view.setUint32(4, length - 8, Endian.little);
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  final blockAlign = channels * bitDepth ~/ 8;
  view.setUint32(28, sampleRate * blockAlign, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitDepth, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  view.setUint32(40, dataLength, Endian.little);
  return bytes;
}

void main() {
  test('accepts structurally consistent 8-bit and 16-bit PCM WAV', () {
    expect(isValidPcmWave(wave()), isTrue);
    expect(isValidPcmWave(wave(bitDepth: 8, dataLength: 1)), isTrue);
  });

  test('rejects a one-byte 16-bit sample and inconsistent rates', () {
    expect(isValidPcmWave(wave(dataLength: 1)), isFalse);
    final wrongRate = wave();
    ByteData.sublistView(wrongRate).setUint32(28, 8000, Endian.little);
    expect(isValidPcmWave(wrongRate), isFalse);
    final wrongAlign = wave();
    ByteData.sublistView(wrongAlign).setUint16(32, 1, Endian.little);
    expect(isValidPcmWave(wrongAlign), isFalse);
  });

  test('rejects invalid format, channels, bit depth and chunk bounds', () {
    final invalidFormat = wave();
    ByteData.sublistView(invalidFormat).setUint16(20, 3, Endian.little);
    expect(isValidPcmWave(invalidFormat), isFalse);
    expect(isValidPcmWave(wave(channels: 0)), isFalse);
    expect(isValidPcmWave(wave(bitDepth: 7)), isFalse);
    final truncated = wave().sublist(0, 45);
    expect(isValidPcmWave(Uint8List.fromList(truncated)), isFalse);
    final overrun = wave();
    ByteData.sublistView(overrun).setUint32(40, 100, Endian.little);
    expect(isValidPcmWave(overrun), isFalse);
  });

  test('requires whole target in word–sentence–word script', () {
    expect(
      isValidDictationTranscript(
        transcript: 'Garden. Please write garden in your book. Garden.',
        targetWord: 'garden',
      ),
      isTrue,
    );
    for (final transcript in [
      'garden',
      'garden. garden. garden.',
      'garden. Please write gardening in your book. garden.',
      'garden. Please write garden in your book. gardening.',
      'garden. Please write garden in your book.',
    ]) {
      expect(
        isValidDictationTranscript(
          transcript: transcript,
          targetWord: 'garden',
        ),
        isFalse,
        reason: transcript,
      );
    }
  });
}
