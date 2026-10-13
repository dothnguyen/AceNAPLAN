void validatePilotPlatform({
  required bool isWeb,
  required bool isWindows,
  required bool qaHarness,
}) {
  if ((isWeb || isWindows) && !qaHarness) {
    throw StateError('Web and Windows require PILOT_QA_HARNESS=true.');
  }
  if (!isWeb && !isWindows && qaHarness) {
    throw StateError('PILOT_QA_HARNESS is only permitted on Web or Windows.');
  }
}
