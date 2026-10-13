import 'package:ace_naplan5/src/pilot_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(720, 1100), // portrait-proportioned desktop window
    const Size(1440, 900), // landscape-proportioned desktop window
  ]) {
    testWidgets('Windows evaluation layout works at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PilotApp(testMode: true));

      expect(find.text('Evaluation mode — progress resets on exit or reload'),
          findsOneWidget);
      expect(find.text('Numeracy'), findsOneWidget);
      expect(find.text('Conventions of Language'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
