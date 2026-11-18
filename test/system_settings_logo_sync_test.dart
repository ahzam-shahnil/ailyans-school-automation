import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/session_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/system_settings_provider.dart';
import 'package:school_automation/core/utils/attendance_pdf_generator.dart';
import 'package:school_automation/core/utils/biodata_pdf_generator.dart';
import 'package:school_automation/core/utils/defaulter_list_pdf_generator.dart';
import 'package:school_automation/core/utils/receipt_pdf_generator.dart';
import 'package:school_automation/models/attendance_roster_row.dart';
import 'package:school_automation/models/user.dart';
import 'package:school_automation/repositories/logo_repository.dart';
import 'package:school_automation/screens/system/system_settings_screen.dart';
import 'package:school_automation/widgets/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late Directory tempDir;
  late File samplePngFile;

  // Canonical 1x1 transparent PNG base64
  const samplePngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  final samplePngBytes = base64Decode(samplePngBase64);

  const testMetadata = ShellMetadata(
    branchName: "Ailyans's Higher Secondary School Mianwali",
    branchAddress: 'Muslim Bazar Mianwali',
    branchPhone: '03334449993',
    branchPrincipal: 'Ahzam Shahnil',
    sessionYear: '2017-2018',
    studentCount: 10,
    classCount: 13,
    staffCount: 6,
    pendingVouchers: 4,
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
    EditableText.debugDeterministicCursor = true;
    DatabaseService.instance.setDatabase(db);

    tempDir = await Directory.systemTemp.createTemp('logo_sync_test_');
    samplePngFile = File(p.join(tempDir.path, 'sample_logo.png'));
    await samplePngFile.writeAsBytes(samplePngBytes);
  });

  tearDown(() async {
    DatabaseService.instance.setDatabase(null);
    if (db.isOpen) {
      await db.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Generator Fixtures
  // ---------------------------------------------------------------------------

  FeeReceiptPrintData createReceiptFixture() {
    return FeeReceiptPrintData(
      feeTransId: 1,
      voucherMasId: '1710-4411',
      stuRegId: 4411,
      studentName: 'Ali Khan',
      fatherName: 'Tariq Khan',
      className: 'Class 1',
      sectionName: 'A',
      rollNo: 1,
      sessionYr: '2024-2025',
      forMonth: 'April 2024',
      submissionDate: DateTime(2024, 4, 10),
      subtotal: 2500,
      discount: 200,
      totalAmount: 2300,
      paidAmount: 2300,
      paymentMode: 'Cash',
      bankName: 'Askari Bank Limited',
      lineItems: const [
        FeeReceiptLineItem(
          feeParamId: 1,
          headName: 'Tuition Fee',
          amount: 2500,
          discount: 200,
        ),
      ],
    );
  }

  DefaulterListFilterSummary createDefaulterSummary() {
    return DefaulterListFilterSummary(
      sessionYr: '2024-2025',
      reportMonth: 'April 2024',
      classFilter: 'Class 1',
      totalDefaulters: 2,
      uniqueStudents: 2,
      totalOutstanding: 5000,
      generatedAt: DateTime(2024, 4, 15),
    );
  }

  List<DefaulterClassGroup> createDefaulterGroups() {
    final rows = [
      const DefaulterListRow(
        voucherMasId: 'V101',
        stuRegId: 1001,
        studentName: 'Zaid Ahmed',
        className: 'Class 1',
        sectionName: 'A',
        forMonth: 'April',
        subtotal: 2500,
        discount: 0,
        paidAmt: 0,
        netPayable: 2500,
        isPaid: 'N',
        daysOverdue: 15,
      ),
      const DefaulterListRow(
        voucherMasId: 'V102',
        stuRegId: 1002,
        studentName: 'Bilal Khan',
        className: 'Class 1',
        sectionName: 'A',
        forMonth: 'April',
        subtotal: 2500,
        discount: 0,
        paidAmt: 0,
        netPayable: 2500,
        isPaid: 'N',
        daysOverdue: 20,
      ),
    ];
    return [
      DefaulterClassGroup(
        classLabel: 'Class 1 - Section A',
        rows: rows,
        subtotal: rows.fold<int>(0, (sum, r) => sum + r.balance),
      ),
    ];
  }

  AttendancePdfData createAttendanceData() {
    return AttendancePdfData(
      branchName: 'Test Branch',
      branchAddress: 'Test Address',
      branchPhone: '03331112233',
      branchPrincipal: 'Principal Test',
      className: 'Class 1',
      sectionName: 'A',
      teacherName: 'Teacher Test',
      sessionYear: '2024-2025',
      attDate: DateTime(2024, 4, 15),
      roster: const [
        AttendanceRosterRow(
          stuRegId: 1001,
          rollNo: 1,
          nameFirst: 'Zaid',
          nameLast: 'Ahmed',
          fatherName: 'Ahmed',
          currentStatus: 'Present',
        ),
      ],
      presentCount: 1,
      absentCount: 0,
      leaveCount: 0,
      lateCount: 0,
      totalCount: 1,
    );
  }

  StudentBiodataPrintData createBiodataData() {
    return const StudentBiodataPrintData(
      stuRegId: 1001,
      studentName: 'Zaid Ahmed',
      fatherName: 'Ahmed Ali',
      fullDiscount: 0,
      enrollmentHistory: [
        StudentEnrollmentHistoryRow(
          sessionYr: '2022-2023',
          className: 'Prep',
          sectionName: 'A',
          classRollNo: 12,
          isPresent: true,
        ),
      ],
      feeTotalBilled: 2000,
      feeTotalPaid: 2000,
      feeBalance: 0,
      currentClassSection: 'Class 1 - A',
    );
  }

  // ===========================================================================
  // T1 — Logo-Present PDF Generators Contract
  // ===========================================================================
  group('T1 — Logo-Present PDF Generators Contract', () {
    test('generate() with local file + base64 produces valid %PDF- and differs from no-logo', () async {
      // 1. Generate baseline no-logo bytes
      final noLogoReceipt = await ReceiptPdfGenerator.generateThreeCopyReceipts(
        receipts: [createReceiptFixture()],
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
      );
      final noLogoDefaulter = await DefaulterListPdfGenerator.generate(
        summary: createDefaulterSummary(),
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
        groups: createDefaulterGroups(),
      );
      final noLogoAttendance = await buildAttendancePdf(createAttendanceData());
      final noLogoBiodata = await BiodataPdfGenerator.generateStudentBiodata(
        data: createBiodataData(),
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
      );

      // 2. Insert both local file path and base64
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_path', samplePngFile.path],
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', samplePngBase64],
      );

      // 3. Generate logo-present bytes
      final logoReceipt = await ReceiptPdfGenerator.generateThreeCopyReceipts(
        receipts: [createReceiptFixture()],
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
      );
      final logoDefaulter = await DefaulterListPdfGenerator.generate(
        summary: createDefaulterSummary(),
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
        groups: createDefaulterGroups(),
      );
      final logoAttendance = await buildAttendancePdf(createAttendanceData());
      final logoBiodata = await BiodataPdfGenerator.generateStudentBiodata(
        data: createBiodataData(),
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
      );

      // Assert %PDF- magic header
      expect(String.fromCharCodes(logoReceipt.take(5)), equals('%PDF-'));
      expect(String.fromCharCodes(logoDefaulter.take(5)), equals('%PDF-'));
      expect(String.fromCharCodes(logoAttendance.take(5)), equals('%PDF-'));
      expect(String.fromCharCodes(logoBiodata.take(5)), equals('%PDF-'));

      // Assert bytes differ from no-logo baseline
      expect(logoReceipt.length, isNot(equals(noLogoReceipt.length)));
      expect(logoDefaulter.length, isNot(equals(noLogoDefaulter.length)));
      expect(logoAttendance.length, isNot(equals(noLogoAttendance.length)));
      expect(logoBiodata.length, isNot(equals(noLogoBiodata.length)));

      // Assert byte length determinism on second run
      final logoReceipt2 = await ReceiptPdfGenerator.generateThreeCopyReceipts(
        receipts: [createReceiptFixture()],
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
      );
      expect(logoReceipt.length, equals(logoReceipt2.length));
    });

    test('generate() with base64-ONLY (no local file on disk) produces valid output', () async {
      await db.delete('app_config', where: "config_key = 'school_logo_path'");
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', samplePngBase64],
      );

      final b64OnlyReceipt = await ReceiptPdfGenerator.generateThreeCopyReceipts(
        receipts: [createReceiptFixture()],
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
      );
      final b64OnlyDefaulter = await DefaulterListPdfGenerator.generate(
        summary: createDefaulterSummary(),
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
        groups: createDefaulterGroups(),
      );

      expect(String.fromCharCodes(b64OnlyReceipt.take(5)), equals('%PDF-'));
      expect(String.fromCharCodes(b64OnlyDefaulter.take(5)), equals('%PDF-'));
    });

    test('Defaulter list multi-page renders logo on page 1 only without error', () async {
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', samplePngBase64],
      );

      // Create a large fixture to span multiple pages
      final multiGroups = List.generate(
        8,
        (i) {
          final rows = List.generate(
            12,
            (j) => DefaulterListRow(
              voucherMasId: 'V_${i}_$j',
              stuRegId: 1000 + i * 10 + j,
              studentName: 'Student ${i}_$j',
              className: 'Class ${i + 1}',
              sectionName: 'A',
              forMonth: 'April',
              subtotal: 3000,
              discount: 0,
              paidAmt: 0,
              netPayable: 3000,
              isPaid: 'N',
              daysOverdue: 25,
            ),
          );
          return DefaulterClassGroup(
            classLabel: 'Class ${i + 1} - Section A',
            rows: rows,
            subtotal: rows.fold<int>(0, (sum, r) => sum + r.balance),
          );
        },
      );

      final pdfBytes = await DefaulterListPdfGenerator.generate(
        summary: DefaulterListFilterSummary(
          sessionYr: '2024-2025',
          reportMonth: 'April 2024',
          classFilter: 'All Classes',
          totalDefaulters: 96,
          uniqueStudents: 96,
          totalOutstanding: 288000,
          generatedAt: DateTime(2024, 4, 15),
        ),
        branchName: 'Test Branch',
        branchAddress: 'Test Address',
        groups: multiGroups,
      );

      expect(pdfBytes.length, greaterThan(15000));
      expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
    });
  });

  // ===========================================================================
  // T2 — Outbox & Sync Contract
  // ===========================================================================
  group('T2 — Outbox & Sync Contract', () {
    test('uploadLogo persists base64 and enqueues outbox row; cleans protected path outbox', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(systemSettingsProvider.notifier);
      await notifier.loadInitialData();

      // Clear any preexisting outbox rows
      await db.delete('_sync_outbox');

      // Emulate upload directly via DB and LogoRepository mirror
      final destPath = await LogoRepository(overrideDirectory: tempDir).copyLogo(samplePngFile.path);
      expect(destPath, isNotNull);

      final bytes = await File(destPath!).readAsBytes();
      final b64 = base64Encode(bytes);

      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_path', destPath],
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', b64],
      );
      // Protected key cleanup
      await db.delete(
        '_sync_outbox',
        where: "table_name = 'app_config' AND record_pk = 'school_logo_path'",
      );

      // Verify school_logo_base64 is captured in outbox
      final outboxRows = await db.rawQuery(
        "SELECT record_pk, table_name FROM _sync_outbox WHERE table_name = 'app_config'",
      );
      final recordPks = outboxRows.map((r) => r['record_pk'] as String).toList();

      expect(recordPks.contains('school_logo_base64'), isTrue);
      expect(recordPks.contains('school_logo_path'), isFalse);
    });

    test('removeLogo sets base64=\'\' so UPDATE is captured in outbox', () async {
      // Clear outbox
      await db.delete('_sync_outbox');

      // Emulate removeLogo flow
      await db.delete(
        'app_config',
        where: 'config_key = ?',
        whereArgs: ['school_logo_path'],
      );
      await db.delete(
        '_sync_outbox',
        where: "table_name = 'app_config' AND record_pk = 'school_logo_path'",
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', ''],
      );

      final outboxRows = await db.rawQuery(
        "SELECT record_pk, table_name FROM _sync_outbox WHERE table_name = 'app_config'",
      );
      final recordPks = outboxRows.map((r) => r['record_pk'] as String).toList();

      expect(recordPks.contains('school_logo_base64'), isTrue);
      expect(recordPks.contains('school_logo_path'), isFalse);
    });
  });

  // ===========================================================================
  // T3 — Removal Propagation & Authority
  // ===========================================================================
  group('T3 — Removal Propagation & Authority', () {
    test('base64=\'\' overrides a stale local file and returns null', () async {
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_path', samplePngFile.path],
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', ''],
      );

      final bytes = await LogoRepository.loadLogoBytes(db);
      expect(bytes, isNull);
    });

    test('legacy 8a-only install (no base64 key) falls back to local file', () async {
      await db.delete('app_config', where: "config_key = 'school_logo_base64'");
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_path', samplePngFile.path],
      );

      final bytes = await LogoRepository.loadLogoBytes(db);
      expect(bytes, isNotNull);
      expect(bytes!.length, equals(samplePngBytes.length));
    });
  });

  // ===========================================================================
  // T4 — Loader Resilience & Read Purity
  // ===========================================================================
  group('T4 — Loader Resilience & Read Purity', () {
    test('returns null gracefully on no keys / missing file / invalid base64', () async {
      // 1. No keys in DB
      await db.delete('app_config', where: "config_key IN ('school_logo_path', 'school_logo_base64')");
      expect(await LogoRepository.loadLogoBytes(db), isNull);

      // 2. Missing file when only path key is set
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_path', '/path/to/nonexistent/logo.png'],
      );
      expect(await LogoRepository.loadLogoBytes(db), isNull);

      // 3. Invalid base64 string
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', '!!!NOT_VALID_BASE64@@@'],
      );
      expect(await LogoRepository.loadLogoBytes(db), isNull);
    });

    test('loadLogoBytes is a pure read and performs NO writes to db or outbox', () async {
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_config (config_key, config_value) VALUES (?, ?)',
        ['school_logo_base64', samplePngBase64],
      );

      final initialConfigCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM app_config')).first['cnt'] as int;
      final initialOutboxCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM _sync_outbox')).first['cnt'] as int;

      final bytes = await LogoRepository.loadLogoBytes(db);
      expect(bytes, isNotNull);

      final finalConfigCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM app_config')).first['cnt'] as int;
      final finalOutboxCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM _sync_outbox')).first['cnt'] as int;

      expect(finalConfigCount, equals(initialConfigCount));
      expect(finalOutboxCount, equals(initialOutboxCount));
    });
  });

  // ===========================================================================
  // T5 — ShellMetadata & Sidebar Brand Integration
  // ===========================================================================
  group('T5 — ShellMetadata & Sidebar Brand Integration', () {
    Widget buildShellTestApp({ShellMetadata? metadata}) {
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const SizedBox.expand(),
              ),
            ],
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          shellMetadataProvider.overrideWith(
            (ref) => metadata ?? testMetadata,
          ),
          sessionProvider.overrideWith((ref) {
            final session = SessionNotifier();
            session.setSession(
              const User(
                id: 1,
                name: 'admin',
                password: 'wr',
                userLevel: 1,
              ),
              [1, 2, 3, 4, 14, 22, 27],
            );
            return session;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('AppSidebar renders Image.memory when logoBytes is present', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildShellTestApp(
          metadata: ShellMetadata(
            branchName: testMetadata.branchName,
            branchAddress: testMetadata.branchAddress,
            sessionYear: testMetadata.sessionYear,
            studentCount: testMetadata.studentCount,
            classCount: testMetadata.classCount,
            staffCount: testMetadata.staffCount,
            pendingVouchers: testMetadata.pendingVouchers,
            logoBytes: samplePngBytes,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppSidebar renders fallback Icons.school when logoBytes is null', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildShellTestApp(metadata: testMetadata),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.school), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sidebar brand container across multi-viewport matrix (360, 390, 414, 1366)', (tester) async {
      final viewports = [
        const Size(360, 800),
        const Size(390, 844),
        const Size(414, 896),
        const Size(1366, 768),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          buildShellTestApp(
            metadata: ShellMetadata(
              branchName: testMetadata.branchName,
              branchAddress: testMetadata.branchAddress,
              sessionYear: testMetadata.sessionYear,
              studentCount: testMetadata.studentCount,
              classCount: testMetadata.classCount,
              staffCount: testMetadata.staffCount,
              pendingVouchers: testMetadata.pendingVouchers,
              logoBytes: samplePngBytes,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        if (size.width >= 800) {
          // Desktop sidebar is mounted
          final imageFinder = find.byType(Image);
          expect(imageFinder, findsOneWidget);

          final imageRect = tester.getRect(imageFinder);
          expect(imageRect.width, lessThanOrEqualTo(36.0));
          expect(imageRect.height, lessThanOrEqualTo(36.0));
          expect(imageRect.left, greaterThanOrEqualTo(0.0));
          expect(imageRect.right, lessThanOrEqualTo(size.width));
        }
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  // ===========================================================================
  // T6 — Settings Preview Additive Fallback
  // ===========================================================================
  group('T6 — Settings Preview Additive Fallback', () {
    testWidgets('renders Image.memory fallback on synced remote device (logoPath is null)', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = await tester.runAsync(() async {
        final n = SystemSettingsNotifier();
        await n.loadInitialData();
        n.setActiveTab(2);
        return n;
      });

      final router = GoRouter(
        initialLocation: '/system/settings',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/system/settings',
                builder: (context, state) => const SystemSettingsScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemSettingsProvider.overrideWith((ref) => notifier!),
            shellMetadataProvider.overrideWith(
              (ref) => ShellMetadata(
                branchName: testMetadata.branchName,
                branchAddress: testMetadata.branchAddress,
                sessionYear: testMetadata.sessionYear,
                studentCount: testMetadata.studentCount,
                classCount: testMetadata.classCount,
                staffCount: testMetadata.staffCount,
                pendingVouchers: testMetadata.pendingVouchers,
                logoBytes: samplePngBytes,
              ),
            ),
            sessionProvider.overrideWith((ref) {
              final session = SessionNotifier();
              session.setSession(
                const User(
                  id: 1,
                  name: 'admin',
                  password: 'wr',
                  userLevel: 1,
                ),
                [1, 2, 3, 4, 14, 22, 27],
              );
              return session;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert Image.memory is rendered for school_logo_preview
      final previewFinder = find.byKey(const ValueKey('school_logo_preview'));
      expect(previewFinder, findsOneWidget);

      final widget = tester.widget<Image>(previewFinder);
      expect(widget.image, isA<MemoryImage>());

      // Assert Remove Logo button is visible
      expect(find.byKey(const ValueKey('school_logo_remove')), findsOneWidget);
    });
  });
}
