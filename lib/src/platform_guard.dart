void validatePilotPlatform({required bool isWeb, required bool qaHarness}) {
  if (isWeb && !qaHarness) {
    throw StateError('Web requires PILOT_QA_HARNESS=true.');
  }
  if (!isWeb && qaHarness) {
    throw StateError('PILOT_QA_HARNESS is not permitted on Android.');
  }
}
