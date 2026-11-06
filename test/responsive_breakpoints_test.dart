import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/utils/responsive_breakpoints.dart';

void main() {
  testWidgets('360x800 is Mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        expect(ResponsiveBreakpoints.isMobile(context), isTrue);
        expect(ResponsiveBreakpoints.isTablet(context), isFalse);
        expect(ResponsiveBreakpoints.isDesktop(context), isFalse);
        return const SizedBox();
      }),
    ));
  });

  testWidgets('768x1024 is Tablet', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        expect(ResponsiveBreakpoints.isMobile(context), isFalse);
        expect(ResponsiveBreakpoints.isTablet(context), isTrue);
        expect(ResponsiveBreakpoints.isDesktop(context), isFalse);
        return const SizedBox();
      }),
    ));
  });

  testWidgets('1440x780 is Desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 780);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        expect(ResponsiveBreakpoints.isMobile(context), isFalse);
        expect(ResponsiveBreakpoints.isTablet(context), isFalse);
        expect(ResponsiveBreakpoints.isDesktop(context), isTrue);
        return const SizedBox();
      }),
    ));
  });
}
