import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/user_management_provider.dart';
import 'package:school_automation/screens/system/user_management_screen.dart';
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

  group('UserManagementScreen & Provider Tests', () {
    test(
      'a) Loads seeded user (Wazahat Raza Zaidi) and auto-selects it',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(userManagementProvider.notifier);
        await notifier.loadUsers();

        final state = container.read(userManagementProvider);
        expect(state.users, isNotEmpty);
        expect(state.selectedUser?.name, 'Wazahat Raza Zaidi');
        expect(state.selectedUser?.id, 1);
        expect(state.isCreatingNew, isFalse);
      },
    );

    test('b) Clicking [+ New User] clears form and defaults UserLvl = 2, isActive = true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers();
      notifier.startNewUser();

      final state = container.read(userManagementProvider);
      expect(state.selectedUser, isNull);
      expect(state.isCreatingNew, isTrue);
    });

    test('c) Saving with empty Name shows "Enter User Name Please"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers();
      notifier.startNewUser();

      final res = await notifier.saveUser(
        name: '   ',
        rawPassword: 'password123',
        userLevel: 2,
        isActive: true,
      );
      expect(res, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'Enter User Name Please',
      );
    });

    test('d) Saving new user with empty Password shows "Enter User Name / Password Please"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers();
      notifier.startNewUser();

      final res = await notifier.saveUser(
        name: 'NewOperator',
        rawPassword: '',
        userLevel: 2,
        isActive: true,
      );
      expect(res, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'Enter User Name / Password Please',
      );
    });

    test('e) Saving with password < 8 chars shows "Password must be at least 8 characters"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers();
      notifier.startNewUser();

      final res = await notifier.saveUser(
        name: 'NewOperator',
        rawPassword: 'short',
        userLevel: 2,
        isActive: true,
      );
      expect(res, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'Password must be at least 8 characters',
      );
    });

    test('f) Saving with duplicate username (case-insensitive) shows "User Name already exists"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers();
      notifier.startNewUser();

      final res = await notifier.saveUser(
        name: 'wazahat raza zaidi',
        rawPassword: 'password123',
        userLevel: 2,
        isActive: true,
      );
      expect(res, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'User Name already exists',
      );
    });

    test('g) Saving valid new user hashes password with BCrypt, inserts with MAX(ID)+1, and shows "Record Saved Successfully"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers();
      notifier.startNewUser();

      final res = await notifier.saveUser(
        name: 'Accountant1',
        designation: 'Accounts Officer',
        rawPassword: 'strongPassword2026',
        userLevel: 2,
        isActive: true,
      );
      expect(res, isTrue);

      final state = container.read(userManagementProvider);
      expect(state.toast, 'Record Saved Successfully');
      expect(state.selectedUser?.name, 'Accountant1');
      expect(state.selectedUser?.id, 2);

      final rows = await db.query('Users', where: 'ID = ?', whereArgs: [2]);
      expect(rows, isNotEmpty);
      final storedHash = rows.first['Pwd'] as String;
      expect(storedHash, isNot('strongPassword2026'));
      expect(BCrypt.checkpw('strongPassword2026', storedHash), isTrue);
    });

    test('h) Editing existing user with blank password field preserves existing BCrypt hash', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers(selectUserId: 1);

      final initialUser = container.read(userManagementProvider).selectedUser!;
      final initialHash = initialUser.password;

      final res = await notifier.saveUser(
        name: 'Wazahat Raza Zaidi',
        designation: 'Senior Director',
        rawPassword: '',
        userLevel: 1,
        isActive: true,
      );
      expect(res, isTrue);

      final updatedUser = container.read(userManagementProvider).selectedUser!;
      expect(updatedUser.designation, 'Senior Director');
      expect(updatedUser.password, initialHash);

      final rows = await db.query('Users', where: 'ID = ?', whereArgs: [1]);
      expect(rows.first['Pwd'], initialHash);
      expect(rows.first['Desig'], 'Senior Director');
    });

    test('i) Deactivating currently logged-in user blocks with "Cannot deactivate the currently logged-in user."', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers(selectUserId: 1);

      final res = await notifier.deactivateUser(1, currentLoggedInUserId: 1);
      expect(res, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'Cannot deactivate the currently logged-in user.',
      );

      final resSave = await notifier.saveUser(
        name: 'Wazahat Raza Zaidi',
        rawPassword: '',
        userLevel: 1,
        isActive: false,
        currentLoggedInUserId: 1,
      );
      expect(resSave, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'Cannot deactivate the currently logged-in user.',
      );
    });

    test('j) Deactivating last active Level-1 admin blocks with "Cannot deactivate the last remaining administrator."', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers(selectUserId: 1);

      final res = await notifier.deactivateUser(1, currentLoggedInUserId: 99);
      expect(res, isFalse);
      expect(
        container.read(userManagementProvider).errorMessage,
        'Cannot deactivate the last remaining administrator.',
      );
    });

    test('k) Deactivating a second operator sets IsActive = 0 and shows "User deactivated successfully"', () async {
      await db.insert('Users', {
        'ID': 2,
        'Name': 'SecondOperator',
        'Pwd': 'hash',
        'UserLvl': 2,
        'IsActive': 1,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userManagementProvider.notifier);
      await notifier.loadUsers(selectUserId: 2);

      final res = await notifier.deactivateUser(2, currentLoggedInUserId: 1);
      expect(res, isTrue);
      expect(
        container.read(userManagementProvider).toast,
        'User deactivated successfully',
      );

      final rows = await db.query('Users', where: 'ID = ?', whereArgs: [2]);
      expect(rows.first['IsActive'], 0);
    });

    testWidgets('l) Fits 1440x900 AND 1440x780 without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: UserManagementScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text('OPERATOR DIRECTORY'), findsOneWidget);

      tester.view.physicalSize = const Size(1440, 780);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'm) Clicking [+ New User] enters new mode with NEW OPERATOR ACCOUNT header',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: UserManagementScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('OPERATOR DIRECTORY'), findsOneWidget);
        await tester.tap(find.text('New User (Ctrl+N)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('NEW OPERATOR ACCOUNT'), findsOneWidget);
      },
    );
  });
}
