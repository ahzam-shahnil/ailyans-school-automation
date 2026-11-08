import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/theme/app_theme_tokens.dart';
import 'package:school_automation/widgets/voucher/voucher.dart';

void main() {
  Widget buildTestApp(Widget child, {Size? size, bool disableAnimations = false}) {
    final effectiveSize = size ?? const Size(800, 600);
    return MaterialApp(
      theme: appTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: effectiveSize,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: effectiveSize.width,
              height: effectiveSize.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('VoucherImpactBanner', () {
    testWidgets('1. normal state renders template with VoucharMas', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherImpactBanner(
            state: VoucherImpactState.normal,
            count: 42,
          ),
        ),
      );

      expect(
        find.text('42 vouchers will be created in VoucharMas + VoucharDet'),
        findsOneWidget,
      );
    });

    testWidgets('2. zero state renders 0 vouchers will be created', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherImpactBanner(
            state: VoucherImpactState.zero,
            count: 0,
          ),
        ),
      );

      expect(find.text('0 vouchers will be created'), findsOneWidget);
    });

    testWidgets('3. error state renders supplied errorText', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherImpactBanner(
            state: VoucherImpactState.error,
            count: 0,
            errorText: 'Fix 2 fields to continue',
          ),
        ),
      );

      expect(find.text('Fix 2 fields to continue'), findsOneWidget);
    });

    testWidgets('4. Semantics liveRegion is present', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherImpactBanner(
            state: VoucherImpactState.normal,
            count: 10,
          ),
        ),
      );

      final liveRegionSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      expect(liveRegionSemantics, findsOneWidget);
    });
  });

  group('FeeHeadsAccordion', () {
    final sampleHeads = [
      const FeeHeadItem(feeParamId: 1, name: 'Tuition Fee', amount: 1500, isChecked: true),
      const FeeHeadItem(feeParamId: 2, name: 'Exam Fee', amount: 300, isChecked: true),
      const FeeHeadItem(feeParamId: 3, name: 'Sports Fee', amount: 200, isChecked: false),
    ];

    testWidgets('5. collapsed by default showing summary header', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: sampleHeads,
            isLoading: false,
            errorMessage: null,
            noTariffMessage: null,
            onToggleHead: (_) {},
            onRetry: null,
            onOpenFeeParams: null,
          ),
        ),
      );

      expect(find.text('3 fee heads · Rs 1,800 per student'), findsOneWidget);
      expect(find.text('Tuition Fee'), findsNothing);
    });

    testWidgets('6. tap header expands rows', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: sampleHeads,
            isLoading: false,
            errorMessage: null,
            noTariffMessage: null,
            onToggleHead: (_) {},
            onRetry: null,
            onOpenFeeParams: null,
          ),
        ),
      );

      await tester.tap(find.text('3 fee heads · Rs 1,800 per student'));
      await tester.pumpAndSettle();

      expect(find.text('Tuition Fee'), findsOneWidget);
      expect(find.text('Exam Fee'), findsOneWidget);
      expect(find.text('Sports Fee'), findsOneWidget);
    });

    testWidgets('7. checkbox tap calls onToggleHead with correct feeParamId', (tester) async {
      int? toggledId;
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: sampleHeads,
            isLoading: false,
            errorMessage: null,
            noTariffMessage: null,
            onToggleHead: (id) => toggledId = id,
            onRetry: null,
            onOpenFeeParams: null,
          ),
        ),
      );

      await tester.tap(find.text('3 fee heads · Rs 1,800 per student'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exam Fee'));
      expect(toggledId, 2);
    });

    testWidgets('8. isLoading renders 3 skeleton rows', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: const [],
            isLoading: true,
            errorMessage: null,
            noTariffMessage: null,
            onToggleHead: (_) {},
            onRetry: null,
            onOpenFeeParams: null,
          ),
        ),
      );

      // Expand accordion
      await tester.tap(find.text('0 fee heads · Rs 0 per student'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('fee_head_skeleton_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('fee_head_skeleton_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('fee_head_skeleton_2')), findsOneWidget);
    });

    testWidgets('9. errorMessage renders error card + Retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: const [],
            isLoading: false,
            errorMessage: "Couldn't load fee heads.",
            noTariffMessage: null,
            onToggleHead: (_) {},
            onRetry: () => retried = true,
            onOpenFeeParams: null,
          ),
        ),
      );

      await tester.tap(find.text('0 fee heads · Rs 0 per student'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load fee heads."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('10. noTariffMessage renders info card + Open Fee Parameters', (tester) async {
      bool opened = false;
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: const [],
            isLoading: false,
            errorMessage: null,
            noTariffMessage: 'No fees set up for this class.',
            onToggleHead: (_) {},
            onRetry: null,
            onOpenFeeParams: () => opened = true,
          ),
        ),
      );

      await tester.tap(find.text('0 fee heads · Rs 0 per student'));
      await tester.pumpAndSettle();

      expect(find.text('No fees set up for this class.'), findsOneWidget);
      expect(find.text('Open Fee Parameters'), findsOneWidget);
      await tester.tap(find.text('Open Fee Parameters'));
      expect(opened, isTrue);
    });

    testWidgets('11. Reduce-motion: expands instantly without animation errors', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          FeeHeadsAccordion(
            heads: sampleHeads,
            isLoading: false,
            errorMessage: null,
            noTariffMessage: null,
            onToggleHead: (_) {},
            onRetry: null,
            onOpenFeeParams: null,
          ),
          disableAnimations: true,
        ),
      );

      await tester.tap(find.text('3 fee heads · Rs 1,800 per student'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tuition Fee'), findsOneWidget);
    });
  });

  group('VoucherActionBar', () {
    testWidgets('12. Row layout at >=600 width', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherActionBar(
            impactState: VoucherImpactState.normal,
            count: 10,
            errorText: null,
            isGenerating: false,
            onGenerate: null,
          ),
          size: const Size(800, 200),
        ),
      );

      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('13. Column layout at <600 width', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherActionBar(
            impactState: VoucherImpactState.normal,
            count: 10,
            errorText: null,
            isGenerating: false,
            onGenerate: null,
          ),
          size: const Size(400, 300),
        ),
      );

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('14. Generate button enabled when onGenerate != null', (tester) async {
      bool generated = false;
      await tester.pumpWidget(
        buildTestApp(
          VoucherActionBar(
            impactState: VoucherImpactState.normal,
            count: 10,
            errorText: null,
            isGenerating: false,
            onGenerate: () => generated = true,
          ),
        ),
      );

      await tester.tap(find.text('Generate'));
      expect(generated, isTrue);
    });

    testWidgets('15. Generate button with onGenerate == null shows disabled styling', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const VoucherActionBar(
            impactState: VoucherImpactState.error,
            count: 0,
            errorText: 'Fix 2 fields to continue',
            isGenerating: false,
            onGenerate: null,
          ),
        ),
      );

      final buttonFinder = find.byType(ElevatedButton);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.style?.backgroundColor?.resolve({}), AppColors.surfaceSubtle);
      expect(button.style?.foregroundColor?.resolve({}), AppColors.textMuted);
    });

    testWidgets('16. isGenerating == true shows Generating...', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherActionBar(
            impactState: VoucherImpactState.normal,
            count: 10,
            errorText: null,
            isGenerating: true,
            onGenerate: () {},
          ),
        ),
      );

      expect(find.text('Generating...'), findsOneWidget);
    });
  });

  group('VoucherResultPanel', () {
    testWidgets('17. success renders createdCount and totalAmount', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.success,
            createdCount: 42,
            totalCount: 42,
            totalAmount: 84000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('42 vouchers created'), findsOneWidget);
      expect(find.text('Total: Rs. 84,000'), findsOneWidget);
    });

    testWidgets('18. cancelled renders stopped message', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.cancelled,
            createdCount: 18,
            totalCount: 42,
            totalAmount: 36000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('Stopped. 18 vouchers were created.'), findsOneWidget);
    });

    testWidgets('19. partial renders created and not created counts', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.partial,
            createdCount: 18,
            totalCount: 42,
            totalAmount: 36000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('18 of 42 vouchers created. 24 not created.'), findsOneWidget);
    });

    testWidgets('20. Share button absent when onShare == null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.success,
            createdCount: 10,
            totalCount: 10,
            totalAmount: 20000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('Share'), findsNothing);
    });

    testWidgets('21. Share button present when onShare != null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.success,
            createdCount: 10,
            totalCount: 10,
            totalAmount: 20000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: () {},
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('22. Resume button absent when onResumeRemaining == null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.cancelled,
            createdCount: 10,
            totalCount: 20,
            totalAmount: 20000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('23. Resume button present when onResumeRemaining != null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.cancelled,
            createdCount: 10,
            totalCount: 20,
            totalAmount: 20000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: () {},
          ),
        ),
      );

      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('24. Print/Save buttons present in success state', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.success,
            createdCount: 10,
            totalCount: 10,
            totalAmount: 20000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
        ),
      );

      expect(find.text('Print all'), findsOneWidget);
      expect(find.text('Save PDF'), findsOneWidget);
      expect(find.text('Generate another'), findsOneWidget);
    });

    testWidgets('25. Reduce-motion: renders without animation errors', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          VoucherResultPanel(
            kind: VoucherResultKind.success,
            createdCount: 10,
            totalCount: 10,
            totalAmount: 20000,
            onPrintAll: () {},
            onSavePdf: () {},
            onShare: null,
            onGenerateAnother: () {},
            onResumeRemaining: null,
          ),
          disableAnimations: true,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('10 vouchers created'), findsOneWidget);
    });
  });

  group('VoucherParameterCard', () {
    Widget buildParamCard({int columnCount = 1, String? sessionYearError}) {
      return VoucherParameterCard(
        sessionYear: '2017-2018',
        sessionYears: const ['2016-2017', '2017-2018', '2018-2019'],
        sessionYearError: sessionYearError,
        billingMonth: 'October 2017',
        billingMonths: const ['September 2017', 'October 2017', 'November 2017'],
        billingMonthError: null,
        classId: 13,
        classes: const [(id: 13, label: 'Class 10'), (id: 12, label: 'Class 9')],
        classError: null,
        sectionId: null,
        sections: const [(id: 1, label: 'A'), (id: 2, label: 'B')],
        issueDate: DateTime(2017, 10, 1),
        issueDateError: null,
        dueDate: DateTime(2017, 10, 10),
        dueDateError: null,
        bankId: 1,
        banks: const [(id: 1, label: 'HBL Muslim Bazar')],
        bankError: null,
        columnCount: columnCount,
        onSessionYearChanged: (_) {},
        onBillingMonthChanged: (_) {},
        onClassChanged: (_) {},
        onSectionChanged: (_) {},
        onIssueDateChanged: (_) {},
        onDueDateChanged: (_) {},
        onBankChanged: (_) {},
        onPickIssueDate: () {},
        onPickDueDate: () {},
      );
    }

    testWidgets('26. columnCount 1 stacks fields with increasing y positions', (tester) async {
      await tester.pumpWidget(buildTestApp(buildParamCard(columnCount: 1)));

      final sessionY = tester.getTopLeft(find.text('Session Year *', findRichText: true)).dy;
      final billingY = tester.getTopLeft(find.text('Billing Month *', findRichText: true)).dy;
      expect(billingY, greaterThan(sessionY));
    });

    testWidgets('27. columnCount 2 places Session Year and Billing Month on same row', (tester) async {
      await tester.pumpWidget(buildTestApp(buildParamCard(columnCount: 2)));

      final sessionY = tester.getTopLeft(find.text('Session Year *', findRichText: true)).dy;
      final billingY = tester.getTopLeft(find.text('Billing Month *', findRichText: true)).dy;
      expect(billingY, equals(sessionY));
    });

    testWidgets('28. Renders all 7 field labels', (tester) async {
      await tester.pumpWidget(buildTestApp(buildParamCard()));

      expect(find.text('Session Year *', findRichText: true), findsOneWidget);
      expect(find.text('Billing Month *', findRichText: true), findsOneWidget);
      expect(find.text('Target Class *', findRichText: true), findsOneWidget);
      expect(find.text('Target Section (optional)', findRichText: true), findsOneWidget);
      expect(find.text('Issue Date *', findRichText: true), findsOneWidget);
      expect(find.text('Payment Due Date *', findRichText: true), findsOneWidget);
      expect(find.text('Receiving Bank *', findRichText: true), findsOneWidget);
    });

    testWidgets('29. Error text under Session Year appears when sessionYearError != null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(buildParamCard(sessionYearError: 'Select a session year')),
      );

      expect(find.text('Select a session year'), findsOneWidget);
    });

    testWidgets('30. Tapping Bank dropdown opens menu', (tester) async {
      await tester.pumpWidget(buildTestApp(buildParamCard()));

      expect(find.byType(DropdownButton<int?>), findsWidgets);
      await tester.tap(find.text('HBL Muslim Bazar'));
      await tester.pumpAndSettle();
      expect(find.text('HBL Muslim Bazar'), findsWidgets);
    });

    testWidgets('31. Reduce-motion: renders without issues', (tester) async {
      await tester.pumpWidget(
        buildTestApp(buildParamCard(), disableAnimations: true),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Session Year *', findRichText: true), findsOneWidget);
    });
  });
}
