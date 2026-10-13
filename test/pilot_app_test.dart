import 'package:ace_naplan5/src/pilot_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1180, 820),
  ]) {
    testWidgets('landing remains readable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const PilotApp(testMode: false));
      expect(find.text('Numeracy'), findsOneWidget);
      expect(find.text('Conventions of Language'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text and Web warning stay usable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const PilotApp(testMode: true),
      ),
    );
    expect(find.text('Test mode — progress resets on refresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
