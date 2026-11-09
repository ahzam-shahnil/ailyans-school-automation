// Phase G-9 Shot 1b — Mobile UX tests for FeeParameterScreen (360/390/414).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/fees/fee_parameter_screen.dart';
import 'package:school_automation/widgets/mobile/mobile_status_pill.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

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

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildParameterScreen() {
    return ProviderScope(
      overrides: [
        availableSessionsProvider.overrideWith((ref) async => ['2017-2018']),
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(testUser, const [16, 17, 18, 21]);
          return notifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(testMetadata)),
      ],
      child: const MaterialApp(home: FeeParameterScreen()),
    );
  }

  /// Flushes real async DB work (sqflite_ffi) that pumpAndSettle cannot advance.
  Future<void> flushAsync(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'FeeParameterScreen at 360x800 renders mobile class cards and Add button with zero overflow',
    (tester) async {
      setViewport(tester, const Size(360, 800));
      await tester.pumpWidget(buildParameterScreen());
      await flushAsync(tester);

      expect(tester.takeException(), isNull);

      // Header and tab strip render on mobile.
      expect(find.text('Fee Structure & Bank Setup'), findsOneWidget);
      expect(find.text('1. Class Fee Structure'), findsOneWidget);
      expect(find.text('2. Institutional Bank Accounts'), findsOneWidget);

      // Session selector and class section header.
      expect(find.text('2017-2018'), findsOneWidget);
      expect(find.text('CLASSES'), findsOneWidget);

      // Seeded class cards render (13 classes) with head-count pills.
      expect(find.text('Class 10'), findsOneWidget);
      expect(find.text('Play Group'), findsOneWidget);
      expect(find.text('3 Heads'), findsAtLeastNWidgets(1));
      expect(find.text('0 Heads'), findsAtLeastNWidgets(1));
      expect(find.byType(MobileStatusPill), findsAtLeastNWidgets(13));

      // Sticky primary action.
      expect(find.text('Add Fee Parameter (Ctrl+N)'), findsOneWidget);
    },
  );

  testWidgets(
    'FeeParameterScreen at 390x844 selecting a class renders mobile fee schedule cards and total strip with zero overflow',
    (tester) async {
      setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(buildParameterScreen());
      await flushAsync(tester);

      expect(tester.takeException(), isNull);

      // Default selection (Class 10) shows the fee schedule section.
      expect(find.text('FEE SCHEDULE: Class 10'), findsOneWidget);
      expect(find.text('Tuition Fee'), findsOneWidget);
      expect(find.text('Rs. 1,500.00'), findsOneWidget);
      expect(find.text('Exam Fee'), findsOneWidget);
      expect(find.text('Rs. 300.00'), findsOneWidget);
      expect(find.text('Annual Charges'), findsOneWidget);
      expect(find.text('Rs. 120.00'), findsOneWidget);
      expect(find.text('Total Class Package'), findsOneWidget);
      expect(find.text('Rs. 1,920.00'), findsOneWidget);
      expect(find.byType(MobileStatusPill), findsWidgets);

      // Selecting another class re-renders the schedule for it.
      final class9 = find.text('Class 9');
      await tester.ensureVisible(class9);
      await tester.pump();
      await tester.ensureVisible(class9);
      await tester.tap(class9);
      await flushAsync(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('FEE SCHEDULE: Class 9'), findsOneWidget);
      expect(
        find.text('No fee parameters defined for Class 9 in session 2017-2018.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'FeeParameterScreen at 414x896 switching tabs renders secondary tab content with zero overflow',
    (tester) async {
      setViewport(tester, const Size(414, 896));
      await tester.pumpWidget(buildParameterScreen());
      await flushAsync(tester);

      expect(tester.takeException(), isNull);

      // Switch to the bank accounts tab (horizontal tab strip may need a scroll).
      final banksTab = find.text('2. Institutional Bank Accounts');
      await tester.ensureVisible(banksTab);
      await tester.pump();
      await tester.ensureVisible(banksTab);
      await tester.tap(banksTab);
      await flushAsync(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('1. Class Fee Structure'), findsOneWidget);
      expect(find.text('2. Institutional Bank Accounts'), findsOneWidget);
      expect(find.text('INSTITUTIONAL BANK ACCOUNTS (1)'), findsOneWidget);
      expect(find.text('Askari Bank'), findsOneWidget);
      expect(find.text('Ballo Khel Road'), findsOneWidget);
      expect(find.text('4528'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.byType(MobileStatusPill), findsWidgets);
      expect(find.text('Add Bank Account'), findsOneWidget);

      // Switch back to the class fee structure tab in the other direction.
      final classesTab = find.text('1. Class Fee Structure');
      await tester.ensureVisible(classesTab);
      await tester.pump();
      await tester.ensureVisible(classesTab);
      await tester.tap(classesTab);
      await flushAsync(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('CLASSES'), findsOneWidget);
      expect(find.text('Add Fee Parameter (Ctrl+N)'), findsOneWidget);
    },
  );
}
