// Phase K-6-d item 5: width-triggered compact directory mode tests.
//
// The K-1 lesson: macOS font metrics are ~3-5% narrower than Windows/Linux,
// and Ahem test glyphs are ~2x real font width, so local containment has ~2x
// headroom. These tests pin REAL containment (tester.getRect of the pill vs
// the horizontal scroll viewport rect) at the client's proven laptop widths
// (1366x768, 1280x720) with production-equivalent shell chrome replicated
// (68px collapsed rail + 24px page padding per side + 1px card border).
//
// Existing desktop tests pump the bare screen at 1440x1000 (available 1438 >=
// full floor 1300 => wide mode), which is why the 1366 clip was never caught.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/student_list_row.dart';
import 'package:school_automation/screens/students/student_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Proven chrome (Step 0, file:line in the run report):
  //   rail 68 (app_sidebar.dart:283 collapsed width)
  //   page padding 24/side (student_list_screen.dart:519 EdgeInsets.all(lg))
  //   card border 1/side (student_list_screen.dart:1040 Border.all)
  const double railWidth = 68.0;
  const double pagePaddingPerSide = 24.0;
  const double cardBorderPerSide = 1.0;

  // Full column floor with default _colWidths (contact excluded — it never
  // renders): 40 + 56 + 80 + 12 + (90+80+260+200+130+100+220) + 32 = 1300.
  const double fullFloor = 1300.0;

  // Reference compact floor: 188 + (90+80+200+160+130+100+96) + 16 = 1060.
  const double compactFloor = 1060.0;

  double availableInCard(double physicalWidth) =>
      physicalWidth - railWidth - 2 * pagePaddingPerSide -
      2 * cardBorderPerSide;

  const seededRows = [
    StudentListRow(
      stuRegId: 4411,
      fullName: 'Muhammad Ali Khan',
      fatherName: 'Khan Muhammad',
      className: 'Class 10',
      sectionName: 'A',
      rollNo: 1,
      status: 'Active',
      sessionYr: '2017-2018',
    ),
    StudentListRow(
      stuRegId: 4412,
      fullName: 'Zainab Ahmed',
      fatherName: 'Ahmed Hassan',
      className: 'Class 10',
      sectionName: 'A',
      rollNo: 2,
      status: 'Active',
      sessionYr: '2017-2018',
    ),
  ];

  const seededClasses = [
    SchoolClass(classId: 1, cName: 'Play Group'),
    SchoolClass(classId: 13, cName: 'Class 10'),
  ];

  const seededSections = [
    ClassSec(classSecId: 25, classId: 13, secName: 'A'),
    ClassSec(classSecId: 26, classId: 13, secName: 'B'),
  ];

  Widget createTestApp({
    List<StudentListRow> students = seededRows,
  }) {
    final router = GoRouter(
      initialLocation: '/students',
      routes: [
        GoRoute(
          path: '/students',
          builder: (context, state) => const StudentListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => Scaffold(
                body: Text('Student Profile ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );

    // Chrome-mimicking frame: the table must see production-equivalent
    // constraints (screen width minus the collapsed rail). No sessionProvider
    // override => session == null => canNewAdmission true => Edit renders
    // (same as test/student_list_test.dart).
    return ProviderScope(
      overrides: [
        studentListProvider.overrideWith((ref) {
          final filters = ref.watch(studentListFiltersProvider);
          var list = List<StudentListRow>.from(students);
          if (filters.search.isNotEmpty) {
            final q = filters.search.toLowerCase();
            list = list
                .where((s) =>
                    s.fullName.toLowerCase().contains(q) ||
                    '${s.stuRegId}'.contains(q))
                .toList();
          }
          return Future.value(list);
        }),
        classesProvider.overrideWith((ref) => Future.value(seededClasses)),
        sectionsProvider.overrideWith((ref) => Future.value(seededSections)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              width: railWidth,
              child: ColoredBox(color: Colors.black12),
            ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size physicalSize) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The table's horizontal scroll viewport: the SingleChildScrollView that
  /// is an ancestor of the action pills (the table's _tableHorizontalScroll
  /// viewport). Its rect IS the visible viewport rect — the only valid
  /// containment reference.
  Rect tableViewportRect(WidgetTester tester, Finder pillFinder) {
    final viewport = find.ancestor(
      of: pillFinder,
      matching: find.byType(SingleChildScrollView),
    ).first;
    return tester.getRect(viewport);
  }

  void expectContained(Rect inner, Rect outer, String what) {
    expect(
      inner.left >= outer.left &&
          inner.right <= outer.right &&
          inner.top >= outer.top &&
          inner.bottom <= outer.bottom,
      isTrue,
      reason: '$what rect $inner must be fully inside viewport rect $outer',
    );
  }

  testWidgets(
    'C1: 1366x768 — View/Edit pills fully inside the table scroll viewport',
    (tester) async {
      await pumpAt(tester, const Size(1366, 768));
      expect(tester.takeException(), isNull);

      final viewPills = find.byKey(const ValueKey('student_row_view'));
      final editPills = find.byKey(const ValueKey('student_row_edit'));
      expect(viewPills, findsWidgets);
      expect(editPills, findsWidgets);

      // Compact mode: full label text must NOT render (icon-only pills).
      expect(find.text('View'), findsNothing);
      expect(find.text('Edit'), findsNothing);

      final viewport = tableViewportRect(tester, viewPills.first);
      for (final pill in viewPills.evaluate()) {
        expectContained(
          tester.getRect(find.byWidget(pill.widget)), viewport, 'View pill');
      }
      for (final pill in editPills.evaluate()) {
        expectContained(
          tester.getRect(find.byWidget(pill.widget)), viewport, 'Edit pill');
      }

      // Affordance: the visible horizontal Scrollbar is present.
      expect(find.byType(Scrollbar), findsWidgets);
    },
  );

  testWidgets(
    'C2: 1280x720 — identical containment, zero exceptions',
    (tester) async {
      await pumpAt(tester, const Size(1280, 720));
      expect(tester.takeException(), isNull);

      final viewPills = find.byKey(const ValueKey('student_row_view'));
      final editPills = find.byKey(const ValueKey('student_row_edit'));
      expect(viewPills, findsWidgets);
      expect(editPills, findsWidgets);

      final viewport = tableViewportRect(tester, viewPills.first);
      for (final pill in viewPills.evaluate()) {
        expectContained(
          tester.getRect(find.byWidget(pill.widget)), viewport, 'View pill');
      }
      for (final pill in editPills.evaluate()) {
        expectContained(
          tester.getRect(find.byWidget(pill.widget)), viewport, 'Edit pill');
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'C3: 1440x1000 wide mode — full labels render, compact keys absent',
    (tester) async {
      await pumpAt(tester, const Size(1440, 1000));
      expect(tester.takeException(), isNull);

      // Wide mode: full label pills exactly as at HEAD.
      expect(find.text('View'), findsWidgets);
      expect(find.text('Edit'), findsWidgets);

      // Compact-only keys must be absent in wide mode.
      expect(find.byKey(const ValueKey('student_row_view')), findsNothing);
      expect(find.byKey(const ValueKey('student_row_edit')), findsNothing);

      // Containment still holds in wide mode at 1440.
      final viewLabel = find.text('View').first;
      final viewport = tableViewportRect(tester, viewLabel);
      expectContained(tester.getRect(viewLabel), viewport, 'View label');
    },
  );

  test('C4: compact floor fits proven available at 1366 AND 1280 with >=5% headroom', () {
    final avail1366 = availableInCard(1366);
    final avail1280 = availableInCard(1280);

    // Sanity: the full floor is what forced scrolling before the fix.
    expect(fullFloor, greaterThan(avail1366));

    expect(compactFloor, lessThanOrEqualTo(avail1366),
        reason: 'compact floor must fit 1366 in-card available $avail1366');
    expect(compactFloor, lessThanOrEqualTo(avail1280),
        reason: 'compact floor must fit 1280 in-card available $avail1280');

    final headroom1366 = (avail1366 - compactFloor) / avail1366;
    final headroom1280 = (avail1280 - compactFloor) / avail1280;
    expect(headroom1366, greaterThanOrEqualTo(0.05),
        reason: '1366 headroom ${(headroom1366 * 100).toStringAsFixed(1)}%');
    expect(headroom1280, greaterThanOrEqualTo(0.05),
        reason: '1280 headroom ${(headroom1280 * 100).toStringAsFixed(1)}%');
  });
}
