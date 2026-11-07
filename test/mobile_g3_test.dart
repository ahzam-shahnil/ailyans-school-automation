// Phase G / G-3 — mobile login card and full-screen report preview modal.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/screens/login/login_screen.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login card at 390x844 fits within screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final cardFinder = find.byType(Container).first;
    final cardSize = tester.getSize(cardFinder);
    expect(cardSize.width, lessThanOrEqualTo(358.0));
  });

  testWidgets('ReportPreviewModal at 390x844 is full screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReportPreviewModal(
              request: ReportRequest(type: ReportType.biodata),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final dialogFinder = find.byType(Dialog);
    final dialogSize = tester.getSize(dialogFinder);
    expect(dialogSize.width, equals(390.0));
    expect(dialogSize.height, equals(844.0));
  });

  testWidgets(
    'ReportPreviewModal mobile toolbar renders Close, Share, Print, More actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReportPreviewModal(
                request: ReportRequest(type: ReportType.biodata),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Share PDF'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsOneWidget);
    },
  );
}
