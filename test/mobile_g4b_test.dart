// Phase G / G-4b — mobile student registration wizard at 390x844:
// full-width primary action, hidden keyboard hints, and zero overflow
// across all four steps.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/student_registration_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/screens/students/student_registration_wizard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testClasses = [
    SchoolClass(classId: 13, cName: 'Class 10'),
    SchoolClass(classId: 12, cName: 'Class 9'),
  ];

  const testSections = [
    ClassSec(classSecId: 25, classId: 13, secName: 'A'),
    ClassSec(classSecId: 26, classId: 13, secName: 'B'),
  ];

  final testFeeParameters = [
    {'Fee': 2500, 'ParamDesciption': 'Tuition Fee'},
    {'Fee': 300, 'ParamDesciption': 'Exam Fee'},
  ];

  Widget buildTestWizard() {
    final router = GoRouter(
      initialLocation: '/students/new',
      routes: [
        GoRoute(
          path: '/students/new',
          builder: (context, state) =>
              const Scaffold(body: StudentRegistrationWizard()),
        ),
        GoRoute(
          path: '/students/:id',
          builder: (context, state) => Scaffold(
            body: Text('Student Profile Screen ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/students',
          builder: (context, state) =>
              const Scaffold(body: Text('Students Directory Screen')),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) =>
              const Scaffold(body: Text('Dashboard Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        classesProvider.overrideWith((ref) => testClasses),
        sectionsProvider.overrideWith((ref) => testSections),
        feePreviewProvider.overrideWith((ref, classId) => testFeeParameters),
        siblingDiscoveryProvider.overrideWith((ref, query) => <SiblingInfo>[]),
        studentAdmissionSubmitterProvider.overrideWithValue(
          (draft, {sessionYr}) async => 4421,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void setMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Step 1 at 390x844 renders full-width Save & Continue and Cancel with '
    'zero overflow (tester.takeException() isNull)',
    (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Step 1 of 4: Personal Information'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      final primaryButton = find.ancestor(
        of: find.text('Save & Continue'),
        matching: find.byType(ElevatedButton),
      );
      expect(primaryButton, findsOneWidget);
      expect(
        tester.getSize(primaryButton).width,
        greaterThan(300),
        reason: 'Mobile primary action must span the wizard width',
      );
    },
  );

  testWidgets(
    'Keyboard hints bar ([Tab] Next, [Enter] Save & Continue, [Esc] Cancel) '
    'is hidden on mobile at 390x844',
    (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('[Tab] Next'), findsNothing);
      expect(find.text('[Enter] Save & Continue'), findsNothing);
      expect(find.text('[Esc] Cancel'), findsNothing);
    },
  );

  testWidgets(
    'Steps 2, 3, and 4 at 390x844 render with zero overflow and Step 4 '
    'displays Complete Admission and Back buttons',
    (tester) async {
      setMobileViewport(tester);

      await tester.pumpWidget(buildTestWizard());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudentRegistrationWizard)),
      );

      // Step 1 (index 0)
      expect(tester.takeException(), isNull, reason: 'Step 1 overflowed');

      for (final step in [1, 2, 3]) {
        container.read(wizardStepProvider.notifier).state = step;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Step ${step + 1} overflowed at 390x844',
        );
      }

      expect(find.text('Complete Admission'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    },
  );
}
