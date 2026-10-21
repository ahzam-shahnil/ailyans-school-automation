import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/app.dart';

void main() {
  testWidgets('AilyansApp boots and redirects from splash to Login Screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AilyansApp()));

    // Initial frame shows splash
    expect(find.text("Ailyans School Automation System"), findsOneWidget);

    // Advance clock past the 500ms splash delay to allow navigation to login
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // Redirects unauthenticated user to Login Screen
    expect(find.text('Sign In (Enter)'), findsOneWidget);
    expect(find.text('Operator Account *'), findsOneWidget);
  });
}
