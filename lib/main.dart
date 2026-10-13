import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/pilot_app.dart';
import 'src/platform_guard.dart';

void main() {
  validatePilotPlatform(
    isWeb: kIsWeb,
    isWindows: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
    qaHarness: const bool.fromEnvironment('PILOT_QA_HARNESS'),
  );
  runApp(PilotApp(
    testMode: kIsWeb || defaultTargetPlatform == TargetPlatform.windows,
  ));
}
