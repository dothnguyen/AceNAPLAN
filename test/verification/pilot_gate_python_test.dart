import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Python opaque gate regressions run in PILOT-UNIT-WIDGET', () async {
    final result = await Process.run(
      'python',
      [
        '-m',
        'unittest',
        'discover',
        '-s',
        'scripts/verification/tests',
        '-p',
        'test_*gate*.py',
        '-v',
      ],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr.toString(), contains('Ran 8 tests'));
  });
}
