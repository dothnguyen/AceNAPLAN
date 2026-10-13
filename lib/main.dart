import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/pilot_app.dart';
import 'src/platform_guard.dart';

void main() {
  validatePilotPlatform(
    isWeb: kIsWeb,
    qaHarness: const bool.fromEnvironment('PILOT_QA_HARNESS'),
  );
  runApp(const PilotApp(testMode: kIsWeb));
}
