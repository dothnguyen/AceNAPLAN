import 'package:ace_naplan5/src/platform_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web and Windows require the QA harness; Android rejects it', () {
    expect(
      () => validatePilotPlatform(
          isWeb: true, isWindows: false, qaHarness: false),
      throwsStateError,
    );
    expect(
      () => validatePilotPlatform(
          isWeb: false, isWindows: true, qaHarness: false),
      throwsStateError,
    );
    expect(
      () => validatePilotPlatform(
          isWeb: false, isWindows: false, qaHarness: true),
      throwsStateError,
    );
    expect(
      () =>
          validatePilotPlatform(isWeb: true, isWindows: false, qaHarness: true),
      returnsNormally,
    );
    expect(
      () =>
          validatePilotPlatform(isWeb: false, isWindows: true, qaHarness: true),
      returnsNormally,
    );
    expect(
      () => validatePilotPlatform(
          isWeb: false, isWindows: false, qaHarness: false),
      returnsNormally,
    );
  });
}
