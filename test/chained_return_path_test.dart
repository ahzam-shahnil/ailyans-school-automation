import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_collection_provider.dart';
import 'package:school_automation/core/providers/school_leaving_provider.dart';
import 'package:school_automation/core/providers/student_profile_provider.dart';
import 'package:school_automation/models/student.dart';
import 'package:school_automation/screens/fees/fee_collection_screen.dart';
import 'package:school_automation/screens/students/school_leaving_screen.dart';
import 'package:school_automation/screens/students/student_profile_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await SchemaMigrations.migrate(db);
    await DatabaseSeeder.seedIfEmpty(db);
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);
    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Future<void> pumpQuickly(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!predicate()) {
      if (DateTime.now().isAfter(end)) {
        throw Exception('pumpUntil timed out');
      }
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
  }

  group('Chained Context-Aware Return Path Tests', () {
    testWidgets(
      'a. StudentProfile [Withdraw] navigates with encoded from= param',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? navigatedLocation;

        final testStudent = Student(
          stuRegId: 4810,
          nameFirst: 'Ali',
          nameLast: 'Raza',
          dob: DateTime(2005, 5, 5),
          bFormNo: '38302-1234567-1',
          fName: 'Raza Ahmad',
          cnicNo: '38302-1234567-2',
          occupation: 'Business',
          pAddress: 'Mianwali',
          tAddress: 'Mianwali',
          mobile1: '0300-1112233',
          religion: 'Islam',
          admInClass: 1,
          admClass: 1,
          doAdmission: DateTime(2024, 1, 1),
          discount: 500,
          vmDiscount: 500,
          fullDiscount: 0,
        );

        final testBundle = StudentProfileBundle(
          student: testStudent,
          enrollments: const [],
          vouchers: const [],
          totalBilled: 0,
          totalPaid: 0,
          outstandingArrears: 0,
          classRollNo: 1,
          currentClassName: 'Class 10',
          currentSectionName: 'A',
          fatherName: 'Raza Ahmad',
          mobile1: '0300-1112233',
          feeBalanceSummary: 'Rs. 0',
          advances: const [],
          exams: const [],
          attendance: const [],
        );

        final router = GoRouter(
          initialLocation: '/students/4810?from=%2Fstudents',
          routes: [
            GoRoute(
              path: '/students/leaving',
              builder: (context, state) {
                navigatedLocation = state.uri.toString();
                return const Scaffold(body: Text('Leaving Screen'));
              },
            ),
            GoRoute(
              path: '/students/:id',
              builder: (context, state) =>
                  StudentProfileScreen(studentId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studentProfileProvider(4810).overrideWith((ref) => testBundle),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await pumpQuickly(tester);

        // Tap [Withdraw Student] button
        final withdrawBtn = find.text('Withdraw Student');
        expect(withdrawBtn, findsOneWidget);
        await tester.tap(withdrawBtn);
        await pumpQuickly(tester);

        // Confirmation dialog appears
        expect(find.text('Withdraw Student?'), findsOneWidget);
        final confirmBtn = find.text('Continue to Withdrawal');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await pumpQuickly(tester);

        // Assert navigation carried the encoded from parameter
        expect(navigatedLocation, isNotNull);
        expect(navigatedLocation, contains('studentId=4810'));
        expect(navigatedLocation, contains('from='));
        expect(
          navigatedLocation,
          contains(Uri.encodeComponent('/students/4810')),
        );
      },
    );

    testWidgets('b. SchoolLeaving back button label matches from= param', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation:
            '/students/leaving?studentId=4810&from=%2Fstudents%2F4810',
        routes: [
          GoRoute(
            path: '/students/leaving',
            builder: (context, state) =>
                const Scaffold(body: SchoolLeavingScreen()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await pumpQuickly(tester);

      // When 'from' starts with /students/, back button label should be 'Back to Student Profile'
      expect(find.text('Back to Student Profile'), findsOneWidget);
    });

    testWidgets(
      'c. SchoolLeaving [Pay Arrears] navigates with full chained from= param',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? receiptsNavigatedUrl;

        // Insert student with unpaid dues
        await tester.runAsync(() async {
          await db.execute('''
            INSERT INTO Stu_Reg (Stu_RegID, NameFirst, NameLast, F_Name, FullDiscount)
            VALUES (4810, 'Ali', 'Raza', 'Raza Ahmad', 0)
          ''');
          await db.execute('''
            INSERT INTO VoucharMas (VoucherMasID, SessionYr, ForMonth, SubTotal, Discount, PaidAmt, IsPaid, Student_Class_StuRegID)
            VALUES ('2610-4810', '2026-27', 'Oct-2026', 4000, 0, 0, 'N', 4810)
          ''');
        });

        final router = GoRouter(
          initialLocation:
              '/students/leaving?studentId=4810&from=%2Fstudents%2F4810',
          routes: [
            GoRoute(
              path: '/students/leaving',
              builder: (context, state) =>
                  const Scaffold(body: SchoolLeavingScreen()),
            ),
            GoRoute(
              path: '/fees/receipts',
              builder: (context, state) {
                receiptsNavigatedUrl = state.uri.toString();
                return const Scaffold(body: Text('Receipts Screen'));
              },
            ),
          ],
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await pumpUntil(
          tester,
          () => container.read(schoolLeavingProvider).duesComputed,
        );

        // Tap [Pay Arrears Now]
        final payArrearsBtn = find.text('Pay Arrears Now');
        expect(payArrearsBtn, findsOneWidget);
        await tester.tap(payArrearsBtn);
        await pumpQuickly(tester);

        expect(receiptsNavigatedUrl, isNotNull);
        expect(receiptsNavigatedUrl, contains('studentId=4810'));
        expect(receiptsNavigatedUrl, contains('from='));
        // Contains chained return url back to School Leaving
        expect(
          receiptsNavigatedUrl,
          contains(Uri.encodeComponent('/students/leaving')),
        );
      },
    );

    testWidgets(
      'd. FeeCollection back button label matches "/students/leaving" origin',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/fees/receipts?studentId=4810&from=%2Fstudents%2Fleaving%3FstudentId%3D4810',
          routes: [
            GoRoute(
              path: '/fees/receipts',
              builder: (context, state) =>
                  const Scaffold(body: FeeCollectionScreen()),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await pumpQuickly(tester);

        // Back button renders 'Back to School Leaving'
        expect(find.text('Back to School Leaving'), findsOneWidget);
      },
    );

    testWidgets(
      'e. FeeCollection postPayment invalidates schoolLeavingProvider',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool invalidated = false;

        // Insert student and voucher into SQLite so postPayment DB queries succeed
        await tester.runAsync(() async {
          await db.execute('''
            INSERT INTO Stu_Reg (Stu_RegID, NameFirst, NameLast, F_Name, FullDiscount)
            VALUES (4810, 'Ali', 'Raza', 'Raza Ahmad', 0)
          ''');
          await db.execute('''
            INSERT INTO VoucharMas (VoucherMasID, SessionYr, ForMonth, SubTotal, Discount, PaidAmt, IsPaid, Student_Class_StuRegID)
            VALUES ('2610-4810', '2026-27', 'Oct-2026', 4000, 0, 0, 'N', 4810)
          ''');
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Preload receipt and set bank
        await tester.runAsync(() async {
          await container
              .read(feeCollectionProvider.notifier)
              .lookupVoucher('2610-4810');
        });
        container.read(feeCollectionProvider.notifier).setBankId(1);

        container.listen(schoolLeavingProvider, (previous, next) {
          invalidated = true;
        });

        final router = GoRouter(
          initialLocation: '/fees/receipts?studentId=4810&from=%2Fstudents%2Fleaving%3FstudentId%3D4810',
          routes: [
            GoRoute(
              path: '/fees/receipts',
              builder: (context, state) =>
                  const Scaffold(body: FeeCollectionScreen()),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await pumpQuickly(tester);

        // Post payment
        final postBtn = find.widgetWithText(
          ElevatedButton,
          'Post Payment (Ctrl+Enter)',
        );
        expect(postBtn, findsOneWidget);
        await tester.ensureVisible(postBtn);

        invalidated =
            false; // Reset listener flag right before posting payment!
        await tester.tap(postBtn);
        await pumpUntil(tester, () => invalidated);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify SnackBar with action 'Back to School Leaving'
        expect(
          find.text('Payment posted. Return to School Leaving to issue SLC.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(SnackBarAction, 'Back to School Leaving'),
          findsOneWidget,
        );
        expect(invalidated, isTrue);
      },
    );
  });
}
