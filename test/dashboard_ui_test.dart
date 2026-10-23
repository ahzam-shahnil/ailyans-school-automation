import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/dashboard_metrics_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/screens/dashboard/dashboard_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('DashboardScreen UI & Live Data Integration Tests', () {
    const testMetrics = DashboardMetrics(
      attendancePercent: 80.0,
      presentCount: 8,
      absentCount: 1,
      leaveCount: 1,
      totalStudents: 10,
      monthlyCollected: 10800,
      monthlyExpected: 30000,
      collectionPace: 36,
      activeEnrollment: 10,
      classCount: 13,
      sectionCount: 26,
      pendingVouchers: 9,
      outstandingAmount: 19200,
      recentPayments: [
        RecentPaymentItem(
          submissionDate: '2017-10-20 11:05:00',
          voucherNo: '1710-4420',
          paidAmount: 1800,
          stuRegId: 4420,
          studentName: 'Hassan Akbar',
        ),
        RecentPaymentItem(
          submissionDate: '2017-10-20 10:30:00',
          voucherNo: '1710-4418',
          paidAmount: 1800,
          stuRegId: 4418,
          studentName: 'Ahmed Raza',
        ),
        RecentPaymentItem(
          submissionDate: '2017-10-20 10:15:00',
          voucherNo: '1710-4416',
          paidAmount: 1800,
          stuRegId: 4416,
          studentName: 'Hamza Nadeem',
        ),
        RecentPaymentItem(
          submissionDate: '2017-10-20 09:35:00',
          voucherNo: '1710-4413',
          paidAmount: 1800,
          stuRegId: 4413,
          studentName: 'Bilal Hussain',
        ),
        RecentPaymentItem(
          submissionDate: '2017-10-20 09:22:00',
          voucherNo: '1710-4412',
          paidAmount: 1800,
          stuRegId: 4412,
          studentName: 'Zainab Ahmed',
        ),
        RecentPaymentItem(
          submissionDate: '2017-10-20 09:14:00',
          voucherNo: '1710-4411',
          paidAmount: 1800,
          stuRegId: 4411,
          studentName: 'Muhammad Ali Khan',
        ),
      ],
      classStrength: [
        ClassStrengthItem(
          className: 'Class 10-A',
          enrolled: 10,
          unpaid: 9,
          outstanding: 19200,
        ),
      ],
    );

    const testShellMeta = ShellMetadata(
      branchName: "Ailyans's Higher Secondary School Mianwali",
      branchAddress: 'Muslim Bazar Mianwali',
      branchPhone: null,
      branchPrincipal: null,
      sessionYear: '2017-2018',
      studentCount: 10,
      classCount: 13,
      staffCount: 5,
      pendingVouchers: 9,
    );

    testWidgets(
      'DashboardScreen renders 4 KPI cards, Quick Actions, and 2 data tables',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/students/new',
              builder: (context, state) =>
                  const Scaffold(body: Text('New Student Admission')),
            ),
            GoRoute(
              path: '/fees/receipts',
              builder: (context, state) =>
                  const Scaffold(body: Text('Fee Receipts')),
            ),
            GoRoute(
              path: '/attendance',
              builder: (context, state) =>
                  const Scaffold(body: Text('Mark Attendance')),
            ),
            GoRoute(
              path: '/fees/vouchers',
              builder: (context, state) =>
                  const Scaffold(body: Text('Fee Vouchers')),
            ),
            GoRoute(
              path: '/students',
              builder: (context, state) =>
                  const Scaffold(body: Text('Students Directory')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardMetricsProvider.overrideWith(
                (ref) => Future.value(testMetrics),
              ),
              shellMetadataProvider.overrideWith(
                (ref) => Future.value(testShellMeta),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify Header Elements
        expect(find.textContaining('Operational Overview —'), findsOneWidget);
        expect(find.text('[ Academic Session: 2017-2018 ]'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // 2. Verify 4 KPI Cards
        // Card 1: Attendance shows "80.0%" or "80%" (8 / 10 Present)
        expect(find.text("TODAY'S ATTENDANCE"), findsOneWidget);
        expect(find.text('80.0%'), findsOneWidget);
        expect(find.text('8 / 10 Present'), findsOneWidget);

        // Card 2: Fee collection (Rs. 10,800, 36% Pace, Exp: Rs. 30,000)
        expect(find.text('MONTHLY FEE COLLECTION'), findsOneWidget);
        expect(find.text('Rs. 10,800'), findsOneWidget);
        expect(find.text('36% Pace'), findsOneWidget);
        expect(find.text('Exp: Rs. 30,000'), findsOneWidget);

        // Card 3: Active Enrollment (10 Students, 13 Classes, 26 Sections)
        expect(find.text('ACTIVE ENROLLMENT'), findsOneWidget);
        expect(find.text('10'), findsWidgets);
        expect(find.text('Students'), findsOneWidget);
        expect(find.text('13 Classes, 26 Sections'), findsOneWidget);

        // Card 4: Pending Vouchers (9 Defaulters, Action Req, Total Overdue: Rs. 19,200)
        expect(find.text('PENDING VOUCHERS'), findsOneWidget);
        expect(find.text('9'), findsWidgets);
        expect(find.text('Defaulters'), findsOneWidget);
        expect(find.text('Action Req'), findsOneWidget);
        expect(find.text('Total Overdue: Rs. 19,200'), findsWidgets);

        // 3. Verify Quick Actions Bar
        expect(find.text('QUICK ACTIONS'), findsOneWidget);
        expect(find.text('+ New Admission (Ctrl+N)'), findsOneWidget);
        expect(find.text('Collect Fee'), findsOneWidget);
        expect(find.text('Mark Roll Call'), findsOneWidget);
        expect(find.text('Batch Voucher'), findsOneWidget);

        // 4. Verify Recent Fee Payments Feed (6 rows from seed data)
        expect(find.text('RECENT FEE PAYMENTS FEED'), findsOneWidget);
        expect(find.text('6 transactions logged today'), findsOneWidget);
        expect(find.text('Hassan Akbar'), findsOneWidget);
        expect(find.text('Ahmed Raza'), findsOneWidget);
        expect(find.text('Hamza Nadeem'), findsOneWidget);
        expect(find.text('Bilal Hussain'), findsOneWidget);
        expect(find.text('Zainab Ahmed'), findsOneWidget);
        expect(find.text('Muhammad Ali Khan'), findsOneWidget);
        expect(find.text('#4420'), findsOneWidget);
        expect(find.text('#4411'), findsOneWidget);
        expect(find.text('1710-4420'), findsOneWidget);
        expect(find.text('1710-4411'), findsOneWidget);

        // 5. Verify Class Strength & Fee Defaulter Summary (Class 10-A with 10 enrolled)
        expect(find.text('CLASS STRENGTH & DEFAULTERS'), findsOneWidget);
        expect(find.text('Class 10-A'), findsOneWidget);
        expect(find.text('View Fee Analytics →'), findsOneWidget);
        expect(find.text('Class Rosters →'), findsOneWidget);

        // 6. Verify PENDING VOUCHERS card has InkWell with active onTap
        final pendingVouchersInkWell = find.ancestor(
          of: find.text('PENDING VOUCHERS'),
          matching: find.byType(InkWell),
        );
        expect(pendingVouchersInkWell, findsOneWidget);
        final inkWellWidget = tester.widget<InkWell>(pendingVouchersInkWell);
        expect(inkWellWidget.onTap, isNotNull);

        // 7. Test Quick Action Navigation: Click "+ New Admission (Ctrl+N)"
        await tester.tap(find.text('+ New Admission (Ctrl+N)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('New Student Admission'), findsOneWidget);
      },
    );

    test('SQLite queries produce exact metrics for Dashboard', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      await SchemaMigrations.migrate(db);
      await DatabaseSeeder.seedIfEmpty(db);

      final todayIso = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Attendance query
      final attRows = await db.rawQuery(
        '''
        SELECT
          COUNT(*) as total,
          SUM(CASE WHEN AttStatus = 'Present' THEN 1 ELSE 0 END) as present,
          SUM(CASE WHEN AttStatus = 'Absent' THEN 1 ELSE 0 END) as absent,
          SUM(CASE WHEN AttStatus = 'Leave' THEN 1 ELSE 0 END) as leave
        FROM AttDet ad
        JOIN AttMas am ON ad.AttMasID = am.AttMasID
        WHERE date(am.AttDate) = date('now', 'localtime')
           OR date(am.AttDate) = date('now')
           OR date(am.AttDate) = ?
        ''',
        [todayIso],
      );
      final attTotal = (attRows.first['total'] as int?) ?? 0;
      final attPresent = (attRows.first['present'] as int?) ?? 0;
      final attPct = attTotal > 0 ? (attPresent * 100.0) / attTotal : 0.0;
      expect(attPct, 80.0);
      expect(attPresent, 8);
      expect(attTotal, 10);

      // 2. Monthly collection query
      final feeRows = await db.rawQuery('''
        SELECT
          COALESCE(SUM(SubTotal), 0) as expected,
          COALESCE(SUM(CASE WHEN IsPaid = 'Y' THEN SubTotal ELSE 0 END), 0) as collected
        FROM VoucharMas
        WHERE SessionYr = '2017-2018'
      ''');
      final collected = (feeRows.first['collected'] as int?) ?? 0;
      final expected = (feeRows.first['expected'] as int?) ?? 0;
      expect(collected, 10800);
      expect(expected, 30000);
      expect(((collected * 100) / expected).round(), 36);

      // 3. Pending vouchers query
      final voucherRows = await db.rawQuery('''
        SELECT
          COUNT(*) as pending,
          COALESCE(SUM(SubTotal - COALESCE(Discount, 0)), 0) as outstanding
        FROM VoucharMas
        WHERE IsPaid = 'N'
      ''');
      expect((voucherRows.first['pending'] as int?) ?? 0, 9);
      expect((voucherRows.first['outstanding'] as int?) ?? 0, 19200);

      // 4. Recent payments query
      final paymentRows = await db.rawQuery('''
        SELECT
          ft.SubmissionDate,
          ft.VoucharNo,
          ft.PaidAmount,
          COALESCE(sr.Stu_RegID, CAST(substr(ft.VoucharNo, 6) AS INTEGER)) as Stu_RegID,
          COALESCE(sr.NameFirst, '') as NameFirst,
          COALESCE(sr.NameLast, '') as NameLast
        FROM FeeTransaction ft
        LEFT JOIN VoucharMas vm ON ft.VoucharNo = vm.VoucherMasID
        LEFT JOIN Stu_Reg sr ON (vm.Student_Class_StuRegID = sr.Stu_RegID OR CAST(substr(ft.VoucharNo, 6) AS INTEGER) = sr.Stu_RegID)
        ORDER BY ft.SubmissionDate DESC
        LIMIT 10
      ''');
      expect(paymentRows.length, 6);

      // 5. Class strength query
      final classStrengthRows = await db.rawQuery('''
        SELECT
          CASE
            WHEN cs.SecName IS NOT NULL THEN c.CName || '-' || cs.SecName
            ELSE c.CName
          END as class_name,
          COUNT(DISTINCT sc.Stu_RegID) as enrolled,
          SUM(CASE WHEN vm.IsPaid = 'N' THEN 1 ELSE 0 END) as unpaid,
          SUM(CASE WHEN vm.IsPaid = 'N' THEN (vm.SubTotal - COALESCE(vm.Discount, 0)) ELSE 0 END) as outstanding
        FROM Class c
        LEFT JOIN Student_Class sc ON c.ClassID = sc.ClassID AND sc.Present = 1
        LEFT JOIN ClassSec cs ON sc.ClassSecID = cs.ClassSecID
        LEFT JOIN VoucharMas vm ON vm.ClassID = c.ClassID AND vm.Student_Class_StuRegID = sc.Stu_RegID
        GROUP BY c.ClassID, cs.ClassSecID
        HAVING enrolled > 0
        ORDER BY c.ClassID
      ''');
      expect(classStrengthRows.length, 1);
      expect(classStrengthRows.first['class_name'], 'Class 10-A');
      expect(classStrengthRows.first['enrolled'], 10);
      expect(classStrengthRows.first['unpaid'], 9);
      expect(classStrengthRows.first['outstanding'], 19200);

      await db.close();
    });
  });
}
