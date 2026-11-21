import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:school_automation/core/providers/bulk_enrollment_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/models/enrollment_row.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/students/bulk_enrollment_screen.dart';
import 'package:school_automation/widgets/reports/report_definition.dart';
import 'package:school_automation/widgets/reports/report_preview_modal.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';

class PreloadedBulkEnrollmentNotifier extends BulkEnrollmentNotifier {
  PreloadedBulkEnrollmentNotifier({required bool hasRoster}) {
    state = BulkEnrollmentState(
      selectedClassId: 13,
      selectedSecId: 25,
      selectedSessionYr: '2017-2018',
      isRosterLoaded: hasRoster,
      roster: hasRoster
          ? const [
              EnrollmentRow(
                stuRegId: 4411,
                classRollNo: 1,
                firstName: 'Muhammad Ali',
                lastName: 'Khan',
                fatherName: 'Khan Muhammad',
                present: true,
                className: 'Class 10',
                sectionName: 'A',
                sessionYr: '2017-2018',
              ),
            ]
          : const [],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUser = User(
    id: 1,
    name: 'Administrator',
    designation: 'Principal',
    password: 'securepassword123',
    userLevel: 1,
    isActive: true,
  );

  const testMetadata = ShellMetadata(
    branchName: "Ailyan's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '0459-234567',
    branchPrincipal: 'Prof. Muhammad Tariq',
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 1,
    staffCount: 5,
    pendingVouchers: 2,
  );

  Widget createWidget({required bool hasRoster}) {
    final router = GoRouter(
      initialLocation: '/students/enrollment/bulk',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/students/enrollment/bulk',
              builder: (context, state) => const BulkEnrollmentScreen(),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        bulkEnrollmentProvider.overrideWith(
          (ref) => PreloadedBulkEnrollmentNotifier(hasRoster: hasRoster),
        ),
        classesProvider.overrideWith(
          (ref) => Future.value(const [
            SchoolClass(classId: 13, cName: 'Class 10'),
          ]),
        ),
        sectionsProvider.overrideWith(
          (ref) => Future.value(const [
            ClassSec(classSecId: 25, classId: 13, secName: 'A'),
          ]),
        ),
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(testUser, const [12, 13, 20, 26]);
          return notifier;
        }),
        shellMetadataProvider.overrideWith(
          (ref) => Future.value(testMetadata),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('BulkEnrollmentScreen Print Class Biodata Tests', () {
    testWidgets(
      'tapping Print Class Biodata with empty roster shows error SnackBar and never shows Coming in Phase E',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget(hasRoster: false));
        await tester.pumpAndSettle();

        final printButton = find.widgetWithText(
          OutlinedButton,
          'Print Class Biodata',
        );
        expect(printButton, findsOneWidget);

        await tester.tap(printButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Load a class roster with enrolled students first'),
          findsOneWidget,
        );
        expect(find.text('Coming in Phase E'), findsNothing);
        expect(find.byType(ReportPreviewModal), findsNothing);
      },
    );

    testWidgets(
      'tapping Print Class Biodata with loaded roster opens ReportPreviewModal with locksOrientation: true',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget(hasRoster: true));
        await tester.pumpAndSettle();

        final printButton = find.widgetWithText(
          OutlinedButton,
          'Print Class Biodata',
        );
        expect(printButton, findsOneWidget);

        await tester.tap(printButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));

        // Must NOT show stub SnackBar
        expect(find.text('Coming in Phase E'), findsNothing);

        // Must open ReportPreviewModal
        expect(find.byType(ReportPreviewModal), findsOneWidget);

        final modal = tester.widget<ReportPreviewModal>(
          find.byType(ReportPreviewModal),
        );
        final request = modal.request;

        expect(request.type, ReportType.biodata);
        expect(request.locksOrientation, isTrue);
        expect(request.naturalPageFormat, PdfPageFormat.a4.landscape);
        expect(
          request.fileNameOverride,
          'class_biodata_Class_10_A_2017-2018.pdf',
        );
        expect(request.customBytesBuilderWithFormat, isNotNull);

        // Dismiss modal to complete dialog future
        Navigator.of(tester.element(find.byType(ReportPreviewModal))).pop();
        await tester.pumpAndSettle();
      },
    );
  });
}
