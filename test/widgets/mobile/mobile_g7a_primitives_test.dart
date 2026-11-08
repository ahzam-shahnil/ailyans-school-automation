import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/theme/app_theme_tokens.dart';
import 'package:school_automation/widgets/mobile/mobile_dropdown_field.dart';
import 'package:school_automation/widgets/mobile/mobile_kpi_card.dart';
import 'package:school_automation/widgets/mobile/mobile_status_pill.dart';

void main() {
  testWidgets(
    'MobileStatusPill renders all 5 variants at 360x800 with zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MobileStatusPill(
                    label: 'Success Pill',
                    variant: MobileStatusVariant.success,
                  ),
                  MobileStatusPill(
                    label: 'Warning Pill',
                    variant: MobileStatusVariant.warning,
                  ),
                  MobileStatusPill(
                    label: 'Error Pill',
                    variant: MobileStatusVariant.error,
                  ),
                  MobileStatusPill(
                    label: 'Info Pill',
                    variant: MobileStatusVariant.info,
                  ),
                  MobileStatusPill(
                    label: 'Neutral Pill',
                    variant: MobileStatusVariant.neutral,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Success Pill'), findsOneWidget);
      expect(find.text('Warning Pill'), findsOneWidget);
      expect(find.text('Error Pill'), findsOneWidget);
      expect(find.text('Info Pill'), findsOneWidget);
      expect(find.text('Neutral Pill'), findsOneWidget);

      expect(find.byType(MobileStatusPill), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MobileKpiCard renders long value \'Rs. 1,412,900\' in FittedBox on frame 1 with no overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MobileKpiCard(
                label: 'Net Cash Collections',
                value: 'Rs. 1,412,900',
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AppColors.accentFees,
                accentSoftBg: AppColors.accentFeesSoftBg,
                statusPillText: 'Verified',
                statusVariant: MobileStatusVariant.success,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // Frame 1 check: value text is rendered immediately without animation frames
      expect(find.text('Rs. 1,412,900'), findsOneWidget);
      expect(find.text('Net Cash Collections'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);

      // Tap callback verification
      await tester.tap(find.byType(MobileKpiCard));
      await tester.pump();
      expect(tapped, isTrue);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MobileDropdownField renders full label at 360x800 (no clipped text) and fires onChanged when tapped',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return MobileDropdownField<String>(
                    label: 'Academic Session Year Selection',
                    value: selectedValue,
                    hintText: 'Select Session Year',
                    items: const [
                      DropdownMenuItem(
                        value: '2024-2025',
                        child: Text('2024-2025'),
                      ),
                      DropdownMenuItem(
                        value: '2025-2026',
                        child: Text('2025-2026'),
                      ),
                      DropdownMenuItem(
                        value: '2026-2027',
                        child: Text('2026-2027'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedValue = val;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Academic Session Year Selection'), findsOneWidget);
      expect(find.text('Select Session Year'), findsOneWidget);

      // Open dropdown and select 2025-2026
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2025-2026').last);
      await tester.pumpAndSettle();

      expect(selectedValue, '2025-2026');
      expect(find.text('2025-2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
