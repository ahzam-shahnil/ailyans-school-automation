import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/permission_matrix_provider.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/system/permission_matrix_screen.dart';
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

  group('PermissionMatrixScreen & Provider Tests', () {
    test('a) Loads user info and 27 modules (ObjID 25 excluded) across 6 categories', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(permissionMatrixProvider.notifier);
      await notifier.loadForUser(1);

      final state = container.read(permissionMatrixProvider);
      expect(state.targetUser?.id, 1);
      expect(state.targetUser?.name, 'Wazahat Raza Zaidi');
      expect(state.allModules.length, 27);
      expect(state.allModules.any((m) => m.objId == 25), isFalse);

      // Verify all 6 categories have non-empty matching modules
      for (final cat in moduleCategories) {
        final catMods = state.allModules.where(
          (m) => cat.objIds.contains(m.objId),
        );
        expect(catMods, isNotEmpty);
      }
    });

    test('b) Loads existing assigned ObjIDs (25 for User #1)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(permissionMatrixProvider.notifier);
      await notifier.loadForUser(1);

      final state = container.read(permissionMatrixProvider);
      expect(state.selectedObjIds.length, 25);
    });

    test('c) Toggling a checkbox updates authorized count badge', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(permissionMatrixProvider.notifier);
      await notifier.loadForUser(1);

      expect(
        container.read(permissionMatrixProvider).selectedObjIds.contains(1),
        isTrue,
      );

      notifier.toggleModule(1);
      expect(
        container.read(permissionMatrixProvider).selectedObjIds.length,
        24,
      );
      expect(
        container.read(permissionMatrixProvider).selectedObjIds.contains(1),
        isFalse,
      );

      notifier.toggleModule(1);
      expect(
        container.read(permissionMatrixProvider).selectedObjIds.length,
        25,
      );
      expect(
        container.read(permissionMatrixProvider).selectedObjIds.contains(1),
        isTrue,
      );
    });

    test('d) Select All selects 27, Deselect All clears to 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(permissionMatrixProvider.notifier);
      await notifier.loadForUser(1);

      notifier.selectAll();
      expect(
        container.read(permissionMatrixProvider).selectedObjIds.length,
        27,
      );

      notifier.deselectAll();
      expect(container.read(permissionMatrixProvider).selectedObjIds.length, 0);
    });

    testWidgets(
      'e) Saving with 0 modules prompts "User will have no access to any module. Proceed?"',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: PermissionMatrixScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Click Deselect All
        await tester.tap(find.text('Deselect All'));
        await tester.pump();

        // Tap Save Access Rights
        await tester.tap(find.text('Save Access Rights (Ctrl+S)'));
        await tester.pump();

        expect(
          find.text('User will have no access to any module. Proceed?'),
          findsOneWidget,
        );
      },
    );

    test('f) Saving updates AccRhts via assignUserRights and shows "User Rights updated successfully" (and updates sessionProvider in-place)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set active session for user 1
      final user1 = (await db.query('Users', where: 'ID = 1')).first;
      container.read(sessionProvider.notifier).setSession(
        User.fromMap(user1),
        const [1, 2, 3],
      );

      final notifier = container.read(permissionMatrixProvider.notifier);
      await notifier.loadForUser(1);

      notifier.deselectAll();
      notifier.toggleModule(8);
      notifier.toggleModule(9);

      final res = await notifier.saveRights();
      expect(res, isTrue);
      expect(
        container.read(permissionMatrixProvider).toast,
        'User Rights updated successfully',
      );

      // Check DB
      final rows = await db.query('AccRhts', where: 'UID = 1 ORDER BY ObjID');
      final savedIds = rows.map((r) => r['ObjID'] as int).toList();
      expect(savedIds, [8, 9]);

      // Check session in-place update (user not logged out)
      final session = container.read(sessionProvider);
      expect(session, isNotNull);
      expect(session?.allowedObjIds, containsAll([8, 9]));
      expect(session?.allowedObjIds.length, 2);
    });

    testWidgets('g) Fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PermissionMatrixScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text('USER ACCESS CONTROL MATRIX'), findsOneWidget);

      tester.view.physicalSize = const Size(1440, 780);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
