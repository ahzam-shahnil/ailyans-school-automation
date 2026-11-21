import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/utils/award_certificate_pdf_generator.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/core/utils/tenant_storage.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:school_automation/widgets/shell/app_sidebar.dart';

void main() {
  const adminUser = User(
    id: 1,
    name: 'Admin Test',
    designation: 'Principal',
    password: 'pwd',
    userLevel: 1,
    isActive: true,
  );

  Widget buildTestShell({
    required ShellMetadata metadata,
    required Size screenSize,
  }) {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Dashboard Content')),
              ),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          final notifier = SessionNotifier();
          notifier.setSession(adminUser, const [1, 2, 3, 4, 8]);
          return notifier;
        }),
        shellMetadataProvider.overrideWith((ref) => Future.value(metadata)),
        sidebarExpandedProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('TenantStorage Branding Resolution Unit Tests', () {
    test('Ailyans brand detection', () {
      expect(
        TenantStorage.isAilyansBrand("Ailyans's Higher Secondary School"),
        isTrue,
      );
      expect(
        TenantStorage.isAilyansBrand("Ailyan School"),
        isTrue,
      );
      expect(
        TenantStorage.isAilyansBrand("The Crescent Academy"),
        isFalse,
      );
      expect(
        TenantStorage.isAilyansBrand(null),
        isFalse,
      );
    });

    test('Short brand resolution', () {
      expect(
        TenantStorage.resolveShortBrand("Ailyans's Higher Secondary School"),
        'Ailyans School',
      );
      expect(
        TenantStorage.resolveShortBrand(
          "Ailyans's Higher Secondary School",
          forTopBar: true,
        ),
        'Ailyans HSS',
      );
      expect(
        TenantStorage.resolveShortBrand("The Crescent Academy"),
        'The',
      );
      expect(
        TenantStorage.resolveShortBrand("Crescent Academy"),
        'Crescent',
      );
      expect(
        TenantStorage.resolveShortBrand(""),
        'ByteWave',
      );
      expect(
        TenantStorage.resolveShortBrand(null),
        'ByteWave',
      );
    });

    test('DB basename resolution', () {
      expect(
        TenantStorage.resolveDbBaseName("Ailyans's Higher Secondary School"),
        'SDB_Ailyans.db',
      );
      expect(
        TenantStorage.resolveDbBaseName("The Crescent Academy"),
        'school_default.db',
      );
    });

    test('Full school name resolution', () {
      expect(
        TenantStorage.resolveSchoolName("The Crescent Academy"),
        'The Crescent Academy',
      );
      expect(
        TenantStorage.resolveSchoolName(null),
        'ByteWave School',
      );
      expect(
        TenantStorage.resolveSchoolName(
          const ShellMetadata(
            branchName: "Ailyans's Higher Secondary School Mianwali",
            branchAddress: 'Address',
            sessionYear: '2026',
            studentCount: 10,
            classCount: 2,
            staffCount: 5,
            pendingVouchers: 0,
          ),
        ),
        "Ailyans's Higher Secondary School Mianwali",
      );
    });

    test('Display paths for settings', () {
      expect(
        TenantStorage.resolveDatabaseDisplayPath(),
        '~/Documents/ByteWave/school_default.db',
      );
      expect(
        TenantStorage.resolveBackupsDisplayPath(),
        '~/Documents/ByteWave/backups',
      );
    });
  });

  group('Clean-Tenant Leak Tests', () {
    const cleanMetadata = ShellMetadata(
      branchName: 'The Crescent Academy',
      branchAddress: 'Gulberg III, Lahore',
      branchPhone: '042-35871234',
      branchPrincipal: 'Dr. Tariq Mahmood',
      sessionYear: '2026-2027',
      studentCount: 350,
      classCount: 15,
      staffCount: 25,
      pendingVouchers: 12,
    );

    testWidgets(
      'Clean tenant shell never leaks Ailyan or Mianwali in sidebar, topbar, statusbar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestShell(
            metadata: cleanMetadata,
            screenSize: const Size(1366, 768),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Sidebar renders clean short brand ('The')
        expect(find.text('The'), findsWidgets);
        expect(find.text('Automation v2.0'), findsWidgets);

        // Status bar renders clean DB name ('school_default.db')
        expect(find.text('DB: school_default.db (Online)'), findsOneWidget);

        // Crucial leak assertions: entire widget tree must NOT contain 'Ailyan' or 'Mianwali'
        expect(find.textContaining('Ailyan'), findsNothing);
        expect(find.textContaining('ailyan'), findsNothing);
        expect(find.textContaining('Mianwali'), findsNothing);
        expect(find.textContaining('mianwali'), findsNothing);
      },
    );

    test('Clean tenant PDF generators do not leak Ailyan or Mianwali', () async {
      // 1. Defaulter list generator footer test
      final summary = DefaulterListFilterSummary(
        sessionYr: '2026-2027',
        totalDefaulters: 0,
        uniqueStudents: 0,
        totalOutstanding: 0,
        reportMonth: 'November 2026',
        generatedAt: DateTime(2026, 11, 21),
      );
      final defaulterBytes = await DefaulterListPdfGenerator.generate(
        groups: const [],
        summary: summary,
        branchName: 'The Crescent Academy',
        branchAddress: 'Gulberg III, Lahore',
      );
      final defaulterString = latin1.decode(defaulterBytes, allowInvalid: true);
      expect(defaulterString.contains('Ailyan'), isFalse);
      expect(defaulterString.contains('Mianwali'), isFalse);

      // 2. Award Certificate PDF generator test
      final awardBytes = await AwardCertificatePdfGenerator.generate(
        examName: 'Annual Examinations 2026',
        className: 'Class 10-A',
        student: {'Name': 'Ali Raza', 'RollNo': 1},
        rank: 1,
        branchName: 'The Crescent Academy',
        branchAddress: 'Gulberg III, Lahore',
      );
      final awardString = latin1.decode(awardBytes, allowInvalid: true);
      expect(awardString.contains('Ailyan'), isFalse);
      expect(awardString.contains('Mianwali'), isFalse);
    });
  });

  group('Long-Tenant Overflow Tests (Zero Overflow Guarantee)', () {
    const longMetadata = ShellMetadata(
      branchName:
          'International Pioneer Grammar School of Higher Learning and Professional Studies Global Campus',
      branchAddress:
          'Plot 45-B, Commercial Avenue, Phase VIII, Defense Housing Authority Sector C-4, Metropolitan Area',
      branchPhone: '+92 42 111 222 333',
      branchPrincipal: 'Prof. Muhammad Shams-ul-Haq Qureshi',
      sessionYear: '2026-2027',
      studentCount: 1250,
      classCount: 45,
      staffCount: 85,
      pendingVouchers: 120,
    );

    const testSizes = [
      Size(360, 800), // Narrow mobile
      Size(390, 844), // Modern mobile
      Size(414, 896), // Large mobile
      Size(1366, 768), // Standard desktop
    ];

    for (final size in testSizes) {
      testWidgets(
        'Zero overflow with 90+ char tenant name at ${size.width.toInt()}x${size.height.toInt()}',
        (WidgetTester tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestShell(
              metadata: longMetadata,
              screenSize: size,
            ),
          );
          await tester.pumpAndSettle();

          // Must not throw any overflow exception or error
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
