// Phase G / G-5-2 — mobile VoucherGenerationScreen zero-overflow at 360/390/414.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/core/db/database.dart';
import 'package:school_automation/core/db/migrations.dart';
import 'package:school_automation/core/db/seed_data.dart';
import 'package:school_automation/core/providers/available_sessions_provider.dart';
import 'package:school_automation/core/providers/clock_provider.dart';
import 'package:school_automation/core/providers/shell_metadata_provider.dart';
import 'package:school_automation/core/providers/student_list_provider.dart';
import 'package:school_automation/core/providers/voucher_generation_provider.dart';
import 'package:school_automation/models/school_class.dart';
import 'package:school_automation/models/voucher_preview_row.dart';
import 'package:school_automation/screens/fees/voucher_generation_screen.dart';
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

    // Apply schema migrations, seeds, and fee tariffs
    await SchemaMigrations.migrate(db);
    await DatabaseSeeder.seedIfEmpty(db);
    await DatabaseSeeder.seedFeeTariffsIfEmpty(db);

    // Clean up any pre-seeded October vouchers so cohort generation tests are isolated
    await db.delete('VoucharDet', where: "VoucharMasID LIKE '1710-%'");
    await db.delete('VoucharMas', where: "ForMonth = 'October 2017'");

    // Mark previous September vouchers as paid by default so baseline arrears are 0
    await db.rawUpdate("UPDATE VoucharMas SET IsPaid = 'Y'");

    DatabaseService.instance.setDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.setDatabase(null);
  });

  Widget buildMobileScreen() {
    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2017, 10, 1)),
        availableSessionsProvider.overrideWith(
          (ref) async => ['2017-2018', '2026-27'],
        ),
        shellMetadataProvider.overrideWith(
          (ref) async => const ShellMetadata(
            branchName: "Ailyans's Higher Secondary School Mianwali",
            branchAddress: 'Muslim Bazar Mianwali',
            sessionYear: '2017-2018',
            studentCount: 0,
            classCount: 0,
            staffCount: 0,
            pendingVouchers: 0,
          ),
        ),
        classesProvider.overrideWith(
          (ref) async => [
            const SchoolClass(classId: 13, cName: 'Class 10'),
          ],
        ),
        sectionsProvider.overrideWith(
          (ref) async => [
            const ClassSec(classSecId: 1, classId: 13, secName: 'A'),
          ],
        ),
        voucherBankListProvider.overrideWith(
          (ref) async => [
            const BankOption(
              bankInfoId: 1,
              bankName: 'Askari Bank',
              branch: 'Ballo Khel Road',
              acctNo: '4528',
              isDefault: true,
            ),
          ],
        ),
        voucherClassTariffsProvider(13).overrideWith(
          (ref) async => [
            const FeeHeadSummary(
              feeParamId: 2,
              description: 'Tuition Fee ',
              fee: 1500.0,
            ),
            const FeeHeadSummary(
              feeParamId: 3,
              description: 'Exam Fee',
              fee: 300.0,
            ),
            const FeeHeadSummary(
              feeParamId: 7,
              description: 'Annual Cgarges',
              fee: 120.0,
            ),
          ],
        ),
        voucherGenPreviewProvider.overrideWith(
          (ref) async => [
            const VoucherPreviewRow(
              stuRegId: 4411,
              studentName: 'Muhammad Ali Khan',
              subtotal: 1920,
              arrears: 0,
              discount: 0,
              netPayable: 1920,
              status: VoucherPreviewStatus.ready,
              voucherId: '1710-4411',
            ),
          ],
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: VoucherGenerationScreen()),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildMobileScreen());
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason: 'voucher_generation zero-overflow at $size',
    );

    // Assert loaded state — at least one marker of mobile preview OR
    // mobile config card rendered.
    final markerCount =
        find.textContaining('Batch Generation Parameters').evaluate().length +
        find.textContaining('Generate Vouchers').evaluate().length +
        find.textContaining('Preview').evaluate().length;
    expect(
      markerCount,
      greaterThan(0),
      reason: 'voucher_generation rendered no mobile config/preview at $size',
    );
  }

  testWidgets('VoucherGenerationScreen zero overflow at 360x800', (
    tester,
  ) async {
    await pumpAt(tester, const Size(360, 800));
  });

  testWidgets('VoucherGenerationScreen zero overflow at 390x844', (
    tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));
  });

  testWidgets('VoucherGenerationScreen zero overflow at 414x896', (
    tester,
  ) async {
    await pumpAt(tester, const Size(414, 896));
  });
}
