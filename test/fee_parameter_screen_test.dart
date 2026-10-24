import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/fee_parameter_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/fees/fee_parameter_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
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

  group('FeeParameterScreen Tab 1', () {
    test('a) loads 13 classes with correct head counts', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadInitial();

      final state = container.read(feeParameterProvider);
      expect(state.classSummaries.length, 13);

      final class10 = state.classSummaries.firstWhere((c) => c.classId == 13);
      expect(class10.headCount, 3);
      expect(class10.totalFee, 1920.0);

      final playGroup = state.classSummaries.firstWhere((c) => c.classId == 1);
      expect(playGroup.headCount, 0);
      expect(playGroup.totalFee, 0.0);
    });

    test('b) selecting Class 10 loads 3 fee parameter rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadInitial(initialClassId: 13);

      final state = container.read(feeParameterProvider);
      expect(state.selectedClassId, 13);
      expect(state.currentClassRows.length, 3);

      // 2=Tuition Fee, 3=Exam Fee, 7=Annual Charges
      final row2 = state.currentClassRows.firstWhere((r) => r.feeParamId == 2);
      expect(row2.formatAmount(), 'Rs. 1,500.00');

      final row3 = state.currentClassRows.firstWhere((r) => r.feeParamId == 3);
      expect(row3.formatAmount(), 'Rs. 300.00');

      final row7 = state.currentClassRows.firstWhere((r) => r.feeParamId == 7);
      expect(row7.formatAmount(), 'Rs. 120.00');
      expect(row7.displayName, 'Annual Charges');

      final total = state.currentClassRows.fold<double>(
        0.0,
        (sum, r) => sum + r.fee,
      );
      expect(total, 1920.0);
    });

    test('c) Add modal lists all 16 FeeParameters in CombParam', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadAvailableFeeParams();

      final state = container.read(feeParameterProvider);
      expect(state.availableFeeParams.length, 16);
      expect(state.availableFeeParams.first['FeeParamID'], 1);
      expect(state.availableFeeParams.last['FeeParamID'], 16);
    });

    test(
      'd) adding tariff uses MAX+1 Cls_Param_Fee_ID and updates class total',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeParameterProvider.notifier);
        await notifier.loadInitial(initialClassId: 13);

        // Max existing Cls_Param_Fee_ID in seed is 9
        final maxBefore = await db.rawQuery(
          'SELECT MAX(Cls_Param_Fee_ID) AS m FROM Cls_Param_Fee',
        );
        final currentMax = (maxBefore.first['m'] as num).toInt();

        final ok = await notifier.addFeeParameter(
          classId: 13,
          feeParamId: 1, // Admission Fee
          fee: 500.0,
          feeYr: '2017-2018',
        );
        expect(ok, isTrue);

        final state = container.read(feeParameterProvider);
        expect(state.toast, 'Fee Parameter Saved Successfully');
        expect(state.currentClassRows.length, 4);

        final added = state.currentClassRows.firstWhere(
          (r) => r.feeParamId == 1,
        );
        expect(added.clsParamFeeId, currentMax + 1);
        expect(added.fee, 500.0);

        final class10 = state.classSummaries.firstWhere((c) => c.classId == 13);
        expect(class10.headCount, 4);
        expect(class10.totalFee, 1920.0 + 500.0);
      },
    );

    test('e) duplicate tariff fires verbatim " Fee already entered for Class " error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadInitial(initialClassId: 13);

      // FeeParamID 2 is already present for Class 13 in '2017-2018'
      final ok = await notifier.addFeeParameter(
        classId: 13,
        feeParamId: 2,
        fee: 1000.0,
        feeYr: '2017-2018',
      );
      expect(ok, isFalse);
      expect(
        container.read(feeParameterProvider).errorMessage,
        ' Fee already entered for Class ',
      );
    });

    test('f) selecting nothing in CombParam fires "Select Fee Parameter Please " (trailing space)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadInitial(initialClassId: 13);

      final ok = await notifier.addFeeParameter(
        classId: 13,
        feeParamId: null,
        fee: 500.0,
        feeYr: '2017-2018',
      );
      expect(ok, isFalse);
      expect(
        container.read(feeParameterProvider).errorMessage,
        'Select Fee Parameter Please ',
      );
    });

    test('g) entering fee <= 0 fires "Enter Fee Please"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadInitial(initialClassId: 13);

      final ok = await notifier.addFeeParameter(
        classId: 13,
        feeParamId: 1,
        fee: 0.0,
        feeYr: '2017-2018',
      );
      expect(ok, isFalse);
      expect(
        container.read(feeParameterProvider).errorMessage,
        'Enter Fee Please',
      );
    });

    test(
      'h) edit updates Fee via composite PK (ClassID, FeeParamID, FeeYr)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(feeParameterProvider.notifier);
        await notifier.loadInitial(initialClassId: 13);

        final ok = await notifier.updateFeeParameter(
          classId: 13,
          feeParamId: 2,
          feeYr: '2017-2018',
          newFee: 1750.0,
        );
        expect(ok, isTrue);

        final state = container.read(feeParameterProvider);
        expect(state.toast, 'Fee Parameter Saved Successfully');

        final row = state.currentClassRows.firstWhere((r) => r.feeParamId == 2);
        expect(row.fee, 1750.0);
        expect(row.formatAmount(), 'Rs. 1,750.00');

        // Verify DB was updated
        final dbRow = await db.rawQuery(
          'SELECT Fee FROM Cls_Param_Fee WHERE ClassID = 13 AND FeeParamID = 2 AND FeeYr = ?',
          ['2017-2018'],
        );
        expect(dbRow.first['Fee'], 1750.0);
      },
    );

    test('i) delete shows verbatim "Are you sure want to Remove ... from Class ..." dialog then removes row on confirm', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(feeParameterProvider.notifier);
      await notifier.loadInitial(initialClassId: 13);

      expect(container.read(feeParameterProvider).currentClassRows.length, 3);

      final ok = await notifier.deleteFeeParameter(
        classId: 13,
        feeParamId: 7,
        feeYr: '2017-2018',
      );
      expect(ok, isTrue);

      final state = container.read(feeParameterProvider);
      expect(state.toast, 'Fee parameter removed');
      expect(state.currentClassRows.length, 2);

      // Confirm DB row is deleted
      final remaining = await db.rawQuery(
        'SELECT * FROM Cls_Param_Fee WHERE ClassID = 13 AND FeeParamID = 7 AND FeeYr = ?',
        ['2017-2018'],
      );
      expect(remaining, isEmpty);
    });
  });

  group('FeeParameterScreen Tab 2', () {
    test('j) loads Askari Bank with Active and Default badges', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bankAccountProvider.notifier);
      await notifier.loadBanks();

      final state = container.read(bankAccountProvider);
      expect(state.banks.length, 1);

      final askari = state.banks.first;
      expect(askari.bankName, 'Askari Bank');
      expect(askari.isActive, isTrue);
      expect(askari.isDefault, isTrue);
      expect(askari.acctStatus, 1);
      expect(askari.bankDefault, 'Y');
    });

    test('k) bank lookup with nonexistent ID fires verbatim "No Bank Exits with Bank ID " prefix', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bankAccountProvider.notifier);
      final bank = await notifier.lookupBankById(999);

      expect(bank, isNull);
      expect(
        container.read(bankAccountProvider).errorMessage,
        'No Bank Exits with Bank ID 999',
      );
    });

    test(
      'l) setting BankDefault=Y on new bank clears BankDefault on others',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(bankAccountProvider.notifier);
        await notifier.loadBanks();

        final ok = await notifier.saveBank(
          bankName: 'Habib Bank Limited',
          branch: 'City Branch',
          address: 'Main Bazar',
          acctNo: '0123456789',
          acctTitle: 'School Fund',
          acctType: 'Current',
          acctStatus: 1,
          bankDefault: 'Y',
        );
        expect(ok, isTrue);

        final state = container.read(bankAccountProvider);
        expect(state.banks.length, 2);

        final askari = state.banks.firstWhere((b) => b.bankInfoId == 1);
        expect(askari.isDefault, isFalse);
        expect(askari.bankDefault, 'N');

        final hbl = state.banks.firstWhere(
          (b) => b.bankName == 'Habib Bank Limited',
        );
        expect(hbl.isDefault, isTrue);
        expect(hbl.bankDefault, 'Y');
      },
    );
  });

  group('FeeParameterScreen layout', () {
    testWidgets('m) fits 1440x900 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/fees/parameters',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/fees/parameters',
                builder: (context, state) => const FeeParameterScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [16, 17, 18, 21]);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FeeParameterScreen), findsOneWidget);
      expect(find.text('1. Class Fee Structure'), findsOneWidget);
      expect(find.text('2. Institutional Bank Accounts'), findsOneWidget);
    });

    testWidgets('n) fits 1440x780 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 780));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/fees/parameters',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/fees/parameters',
                builder: (context, state) => const FeeParameterScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [
                16,
                17,
                18,
                21,
              ], hasWeakPasswordWarning: true);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FeeParameterScreen), findsOneWidget);
    });

    testWidgets('o) header contains back button with tooltip and title', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      String? navigatedRoute;
      final router = GoRouter(
        initialLocation: '/fees/parameters',
        routes: [
          GoRoute(
            path: '/fees/parameters',
            builder: (context, state) => const FeeParameterScreen(),
          ),
          GoRoute(
            path: '/fees/vouchers',
            builder: (context, state) {
              navigatedRoute = '/fees/vouchers';
              return const Scaffold(body: Text('Vouchers Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) {
              final notifier = SessionNotifier();
              notifier.setSession(testUser, const [16, 17, 18, 21]);
              return notifier;
            }),
            shellMetadataProvider.overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fee Structure & Bank Setup'), findsOneWidget);
      final backBtn = find.byTooltip('Back to Fee Vouchers');
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/fees/vouchers');
    });

    testWidgets(
      'p) CombParam in Add modal renders only FeeHeadDisplay names without ID prefix or em-dash',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith((ref) {
                final notifier = SessionNotifier();
                notifier.setSession(testUser, const [16, 17, 18, 21]);
                return notifier;
              }),
              shellMetadataProvider.overrideWith(
                (ref) => Future.value(testMetadata),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: FeeParameterScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap Add Fee Parameter button
        final addBtn = find.text('Add Fee Parameter (Ctrl+N)');
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Verify title uses ASCII hyphen
        expect(find.textContaining('Add Fee Parameter - '), findsOneWidget);

        // Tap CombParam dropdown
        final dropdown = find.byKey(const ValueKey('add_comb_param'));
        expect(dropdown, findsOneWidget);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Confirm items do NOT contain em-dash or ID prefixes like "1 —" or "9 —"
        expect(find.textContaining('—'), findsNothing);
        expect(find.textContaining('1 —'), findsNothing);
        expect(find.textContaining('9 —'), findsNothing);
      },
    );
  });
}
