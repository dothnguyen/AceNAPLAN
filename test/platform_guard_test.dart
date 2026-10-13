import 'package:ace_naplan5/src/platform_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web requires the QA harness and Android rejects it', () {
    expect(
      () => validatePilotPlatform(isWeb: true, qaHarness: false),
      throwsStateError,
    );
    expect(
      () => validatePilotPlatform(isWeb: false, qaHarness: true),
      throwsStateError,
    );
    expect(
      () => validatePilotPlatform(isWeb: true, qaHarness: true),
      returnsNormally,
    );
    expect(
      () => validatePilotPlatform(isWeb: false, qaHarness: false),
      returnsNormally,
    );
  });
}
