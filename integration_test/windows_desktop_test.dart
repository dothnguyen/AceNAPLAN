import 'package:ace_naplan5/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows desktop starts in visibly temporary evaluation mode', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(
      find.text('Evaluation mode — progress resets on exit or reload'),
      findsOneWidget,
    );
    expect(find.text('Numeracy'), findsOneWidget);
    expect(find.text('Conventions of Language'), findsOneWidget);
  });
}
