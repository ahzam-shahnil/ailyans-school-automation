// Phase K-6-e items 6+7: teacher profile back button top-left tests.
//
// Containment = tester.getRect against the header row rect (presence is not
// visibility). Desktop asserts the back button is the flush-left first child
// of the identity header row; mobile asserts containment inside the new top
// header row at the Argon Rule 14 sizes (360x800, 390x844, 414x896).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/teacher_profile_provider.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/screens/staff/teacher_profile_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _backKey = ValueKey('profile_back_button');
const _desktopHeaderKey = ValueKey('teacher_desktop_header_row');
const _mobileHeaderKey = ValueKey('teacher_mobile_header_row');

const _testUser = User(
  id: 1,
  name: 'Administrator',
  designation: 'Principal',
  password: 'securepassword123',
  userLevel: 1,
  isActive: true,
);

const _readOnlyUser = User(
  id: 2,
  name: 'ReadOnly Viewer',
  designation: 'Viewer',
  password: 'securepassword123',
  userLevel: 3,
  isActive: true,
);

const _testMetadata = ShellMetadata(
  branchName: "Ailyan's Higher Secondary School Mianwali",
  branchAddress: 'Muslim Bazar Mianwali',
  branchPhone: '0459-234567',
  branchPrincipal: 'Prof. Muhammad Tariq',
  sessionYear: '2017-2018',
  studentCount: 10,
  classCount: 1,
  staffCount: 6,
  pendingVouchers: 4,
);

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

  Widget buildTestScreen({
    String initialLocation = '/staff/teachers/1',
    int? teacherId = 1,
    required TeacherProfileNotifier notifier,
    User user = _testUser,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/staff/teachers',
              builder: (context, state) =>
                  const Scaffold(body: Text('Teacher Directory Stub')),
            ),
            GoRoute(
              path: '/staff/teachers/new',
              builder: (context, state) =>
                  const TeacherProfileScreen(isCreateMode: true),
            ),
            GoRoute(
              path: '/staff/teachers/:id',
              builder: (context, state) {
                final idStr = state.pathParameters['id'];
                final id = idStr != null ? int.tryParse(idStr) : null;
                return TeacherProfileScreen(teacherId: id);
              },
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        teacherProfileProvider(teacherId).overrideWith((ref) => notifier),
        sessionProvider.overrideWith((ref) {
          final session = SessionNotifier();
          session.setSession(
            user,
            user.userLevel == 1 ? const [8, 9, 10, 12, 13, 14, 20] : const [],
          );
          return session;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(_testMetadata)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<TeacherProfileNotifier> pumpedNotifier(int teacherId) async {
    late TeacherProfileNotifier notifier;
    await runAsyncLoad(() async {
      notifier = TeacherProfileNotifier();
      await notifier.loadTeacher(teacherId);
    });
    return notifier;
  }

  testWidgets(
    'T1: desktop 1366x768 — back button is flush-left first child of the header row and fully contained',
    (tester) async {
      final notifier = await pumpedNotifier(1);

      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(initialLocation: '/staff/teachers/1', notifier: notifier),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_backKey), findsOneWidget);

      final headerRect = tester.getRect(find.byKey(_desktopHeaderKey));
      final backRect = tester.getRect(find.byKey(_backKey));

      // Flush-left first child: the header Row has no leading padding, so
      // the back button's left edge IS the row's left edge (<= 1px tolerance
      // for the container's own border rounding).
      expect(
        (backRect.left - headerRect.left).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'back button must be the flush-left first child of the '
            'desktop header row (back $backRect vs header $headerRect)',
      );

      expect(
        backRect.left >= headerRect.left &&
            backRect.right <= headerRect.right &&
            backRect.top >= headerRect.top &&
            backRect.bottom <= headerRect.bottom,
        isTrue,
        reason: 'back rect $backRect must be inside header rect $headerRect',
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T2: desktop 1440x900 dirty flow — back triggers the discard confirmation dialog',
    (tester) async {
      final notifier = await pumpedNotifier(1);

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(initialLocation: '/staff/teachers/1', notifier: notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Modify a field to become dirty
      final fatherField = find.widgetWithText(TextFormField, 'Muhammad Ali');
      await tester.enterText(fatherField, 'Dirty Modified Father');
      await tester.pumpAndSettle();

      // Tap the top-left back button
      await tester.tap(find.byKey(_backKey));
      await tester.pumpAndSettle();

      // Discard confirmation dialog appears (dirty flow preserved)
      expect(find.text('Discard Unsaved Changes?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard Changes'), findsOneWidget);

      // Keep Editing stays on page
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(find.text('Discard Unsaved Changes?'), findsNothing);
      expect(find.text('Save Changes (Ctrl+S)'), findsOneWidget);
    },
  );

  testWidgets(
    'T3: mobile 360x800 — back contained in the mobile header row; sticky bar has Edit Profile, no Directory',
    (tester) async {
      final notifier = await pumpedNotifier(1);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(initialLocation: '/staff/teachers/1', notifier: notifier),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final headerRect = tester.getRect(find.byKey(_mobileHeaderKey));
      final backRect = tester.getRect(find.byKey(_backKey));

      expect(
        backRect.left >= headerRect.left &&
            backRect.right <= headerRect.right &&
            backRect.top >= headerRect.top &&
            backRect.bottom <= headerRect.bottom,
        isTrue,
        reason: 'mobile back rect $backRect must be inside header $headerRect',
      );
      // Back is the FIRST child (flush left of the header row).
      expect((backRect.left - headerRect.left).abs(), lessThanOrEqualTo(1.0));

      // Title renders and can ellipsize without overflow.
      expect(find.text('Teacher Profile'), findsOneWidget);

      // Sticky view bar: Edit Profile present, Directory button gone.
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Directory'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T4: mobile 390x844 and 414x896 — containment + zero overflow (Rule 14)',
    (tester) async {
      for (final size in const [Size(390, 844), Size(414, 896)]) {
        final notifier = await pumpedNotifier(1);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestScreen(
            initialLocation: '/staff/teachers/1',
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'no exception at ${size.width}x${size.height}');

        final headerRect = tester.getRect(find.byKey(_mobileHeaderKey));
        final backRect = tester.getRect(find.byKey(_backKey));
        expect(
          backRect.left >= headerRect.left &&
              backRect.right <= headerRect.right &&
              backRect.top >= headerRect.top &&
              backRect.bottom <= headerRect.bottom,
          isTrue,
          reason: 'back $backRect inside header $headerRect at $size',
        );
      }
    },
  );

  testWidgets(
    'T5: mobile readOnly view — sticky bar collapses to SizedBox.shrink; back still top-left',
    (tester) async {
      final notifier = await pumpedNotifier(1);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(
          initialLocation: '/staff/teachers/1',
          notifier: notifier,
          user: _readOnlyUser,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // No empty bordered bar: neither Edit Profile nor any sticky button.
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Directory'), findsNothing);

      // The sticky bar container is absent — no SizedBox.shrink is even
      // mounted as a decorated bar; the outer Column simply has one less
      // child. Verify via the absence of the sticky bar's border container:
      // the back button still sits top-left in the header row.
      final headerRect = tester.getRect(find.byKey(_mobileHeaderKey));
      final backRect = tester.getRect(find.byKey(_backKey));
      expect((backRect.left - headerRect.left).abs(), lessThanOrEqualTo(1.0));
      expect(
        backRect.top >= headerRect.top && backRect.bottom <= headerRect.bottom,
        isTrue,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T6: clean-state back tap navigates to /staff/teachers',
    (tester) async {
      final notifier = await pumpedNotifier(1);

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(initialLocation: '/staff/teachers/1', notifier: notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_backKey));
      await tester.pumpAndSettle();

      expect(find.text('Teacher Directory Stub'), findsOneWidget);
    },
  );
}

/// Runs [body] inside `binding.runAsync` so real async ffi work completes
/// without leaking the tester into the helper's signature.
Future<void> runAsyncLoad(Future<void> Function() body) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.runAsync(body);
}
