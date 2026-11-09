// DEV SEED CREDENTIALS: Wazahat Raza Zaidi / wr
// (legacy password; below 8-char min; warning fires on login)

import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Computes the current academic session year (April-March fiscal year).
/// April 2026 onwards -> '2026-27'; January-March 2026 -> '2025-26'.
String getCurrentSessionYr() {
  final now = DateTime.now();
  final startYear = now.month >= 4 ? now.year : now.year - 1;
  return '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';
}

/// Database seeder to populate minimal initial development and dashboard data.
class DatabaseSeeder {
  /// Seeds initial system, authentication, and dashboard data.
  /// Uses guards to prevent overwriting existing data.
  static Future<void> seedIfEmpty(Database db) async {
    // 1. Guard for Authentication & Access Rights
    final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM Users');
    final userCount = (countResult.first['cnt'] as int?) ?? 0;
    final isFreshInstall = userCount == 0;
    if (isFreshInstall) {
      await _seedUsersAndRights(db);
    }

    // 2. Guard for Dashboard realistic data (Classes, Students, Fees, etc.)
    final classResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM Class');
    final classCount = (classResult.first['cnt'] as int?) ?? 0;
    if (classCount == 0) {
      await _seedDashboardData(db);
    }

    // 3. Guard for FeeParameters (16 catalog fee heads)
    final feeParamResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM FeeParameters',
    );
    final feeParamCount = (feeParamResult.first['cnt'] as int?) ?? 0;
    if (feeParamCount == 0) {
      await _seedFeeParameters(db);
    }

    // 4. Guard for Attendance Data (AttMas + AttDet for Class 10-A)
    final attMasResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM AttMas',
    );
    final attMasCount = (attMasResult.first['cnt'] as int?) ?? 0;
    if (attMasCount == 0) {
      await _seedAttendanceData(db);
    }

    // 5. Fresh installs: anchor the active session on the current academic
    //    year instead of the legacy '2017-2018' fallback. Gated to real
    //    (non-test) launches so test fixtures keep asserting the legacy
    //    fallback, and INSERT OR IGNORE so an existing installation's chosen
    //    session in app_config is never overwritten.
    if (isFreshInstall && !Platform.environment.containsKey('FLUTTER_TEST')) {
      await db.insert('app_config', {
        'config_key': 'default_session_yr',
        'config_value': getCurrentSessionYr(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Seeds core administration: InstBranch, Users, AccObj, AccRhts.
  static Future<void> _seedUsersAndRights(Database db) async {
    await db.transaction((txn) async {
      // 1. InstBranch (1 row)
      // Note: BrnachID preserves legacy schema column typo
      await txn.insert('InstBranch', {
        'BrnachID': 1,
        'InstituteID': 1,
        'BranchName': "Ailyans's Higher Secondary School Mianwali",
        'BranchAddress': 'Muslim Bazar Mianwali',
        'BrPhone': '03334449993',
        'Mobile': '03453333224',
        'BrPrincipal': 'Nasir ali',
        'SecPd': 'zaidi110',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // 2. Users (1 row - Director)
      // Password 'wr' is the legacy plaintext password from Phase A, hashed via BCrypt
      final hashedLegacyPassword = BCrypt.hashpw('wr', BCrypt.gensalt());
      await txn.insert('Users', {
        'ID': 1,
        'Name': 'Wazahat Raza Zaidi',
        'Desig': 'Director',
        'Pwd': hashedLegacyPassword,
        'Br': 'Management',
        'Mobile1': '03336839853',
        'UserLvl': 1,
        'IsActive': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // 3. AccObj (28 rows verbatim from SDB_Ailyans.mdb export)
      const accObjects = [
        {'ObjID': 1, 'ObjName': 'frmAllinOne', 'DisplayName': 'Pricipal Form'},
        {
          'ObjID': 2,
          'ObjName': 'frmAttandance',
          'DisplayName': 'Students Attandance',
        },
        {
          'ObjID': 3,
          'ObjName': 'frmBooks',
          'DisplayName': 'Add / Displaying Books',
        },
        {
          'ObjID': 4,
          'ObjName': 'frmClass',
          'DisplayName': 'Adding / Modifing Classes and Section',
        },
        {
          'ObjID': 5,
          'ObjName': 'frmContCat',
          'DisplayName': 'Category for SMS Contacts',
        },
        {
          'ObjID': 6,
          'ObjName': 'frmCont',
          'DisplayName': 'SMS Contcts List / Draft',
        },
        {
          'ObjID': 7,
          'ObjName': 'frmSMSSend',
          'DisplayName': 'Sending SMS and Setting',
        },
        {
          'ObjID': 8,
          'ObjName': 'frmPromote',
          'DisplayName': 'Class Promotion to Next Session',
        },
        {
          'ObjID': 9,
          'ObjName': 'frmSLeaving',
          'DisplayName': 'Students Leaving and SL Certificate',
        },
        {
          'ObjID': 10,
          'ObjName': 'frmExams',
          'DisplayName': 'New Term and Examination Setup',
        },
        {
          'ObjID': 11,
          'ObjName': 'frmStuAdvance',
          'DisplayName': 'Adding / Modifying Student Advances',
        },
        {
          'ObjID': 12,
          'ObjName': 'frmStuReg',
          'DisplayName': 'Student Registration / Modification',
        },
        {
          'ObjID': 13,
          'ObjName': 'frmStuSearch',
          'DisplayName': 'Finding Student by Name / Class / Present',
        },
        {
          'ObjID': 14,
          'ObjName': 'frmTeachers',
          'DisplayName': 'Add/Modify Teacher and Report',
        },
        {
          'ObjID': 15,
          'ObjName': 'frmUsers',
          'DisplayName': 'Adding Removing SAS Users and Access Rights',
        },
        {
          'ObjID': 16,
          'ObjName': 'frmVoucharRecipt',
          'DisplayName': 'Payment Recipts',
        },
        {
          'ObjID': 17,
          'ObjName': 'frmVoucher',
          'DisplayName': 'Generating / Modifiying / Printing Vouchars',
        },
        {
          'ObjID': 18,
          'ObjName': 'frmVouDet',
          'DisplayName': 'Payment Analysis Reports Printing',
        },
        {
          'ObjID': 19,
          'ObjName': 'SCHfrmBankInfo',
          'DisplayName': 'Adding / Modifing Bank Acctount Info',
        },
        {
          'ObjID': 20,
          'ObjName': 'SCHfrmStu_Class',
          'DisplayName': 'Students Enrollment into Classes',
        },
        {
          'ObjID': 21,
          'ObjName': 'SCHfrmFeeParameter',
          'DisplayName': 'Adding / Setting Fee Structure',
        },
        {
          'ObjID': 22,
          'ObjName': 'frmTSal',
          'DisplayName': 'Teachers and Staff Salary',
        },
        {
          'ObjID': 23,
          'ObjName': 'frmExamClasSubj',
          'DisplayName': 'Setting Exam Subjects for Classes',
        },
        {
          'ObjID': 24,
          'ObjName': 'frmExamMarks',
          'DisplayName': 'Entring Exam Marks for students',
        },
        {
          'ObjID': 25,
          'ObjName': 'frmSubject',
          'DisplayName': 'Class Subjects Categories',
        },
        {
          'ObjID': 26,
          'ObjName': 'frmNewAdmission',
          'DisplayName': 'New Student Admission Procedure',
        },
        {
          'ObjID': 28,
          'ObjName': 'frmTAttandance',
          'DisplayName': 'Staff Attandance',
        },
        {
          'ObjID': 29,
          'ObjName': 'frmTSalSetup',
          'DisplayName': 'Staff salay Setup',
        },
      ];

      for (final obj in accObjects) {
        await txn.insert(
          'AccObj',
          obj,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 4. AccRhts (25 rows for Director UID = 1, excluding SMS objects 5, 6, 7)
      const allowedObjIds = [
        1,
        2,
        3,
        4,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        28,
        29,
      ];

      for (final objId in allowedObjIds) {
        await txn.insert('AccRhts', {
          'UID': 1,
          'ObjID': objId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Seeds realistic test data for the Dashboard (Class, ClassSec, Teachers,
  /// Stu_Reg, Student_Class, VoucharMas, VoucharDet, FeeTransaction, BankInfo).
  static Future<void> _seedDashboardData(Database db) async {
    await db.transaction((txn) async {
      // 1. Class (13 rows)
      const classes = [
        {'ClassID': 1, 'CName': 'Play Group'},
        {'ClassID': 2, 'CName': 'Nursery'},
        {'ClassID': 3, 'CName': 'Prep'},
        {'ClassID': 4, 'CName': 'Class 1'},
        {'ClassID': 5, 'CName': 'Class 2'},
        {'ClassID': 6, 'CName': 'Class 3'},
        {'ClassID': 7, 'CName': 'Class 4'},
        {'ClassID': 8, 'CName': 'Class 5'},
        {'ClassID': 9, 'CName': 'Class 6'},
        {'ClassID': 10, 'CName': 'Class 7'},
        {'ClassID': 11, 'CName': 'Class 8'},
        {'ClassID': 12, 'CName': 'Class 9'},
        {'ClassID': 13, 'CName': 'Class 10'},
      ];

      for (final cls in classes) {
        await txn.insert(
          'Class',
          cls,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 2. ClassSec (26 rows — 2 sections 'A' and 'B' per class)
      var secId = 1;
      for (var classId = 1; classId <= 13; classId++) {
        await txn.insert('ClassSec', {
          'ClassSecID': secId++,
          'ClassID': classId,
          'SecName': 'A',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('ClassSec', {
          'ClassSecID': secId++,
          'ClassID': classId,
          'SecName': 'B',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 3. Teachers (5 rows)
      const teachers = [
        {
          'TeacherID': 1,
          'TName': 'Nasir Ali',
          'TFName': 'Muhammad Ali',
          'TCNIC': '38302-1111111-1',
          'TContactNo1': '03331111111',
          'TSubject': 'Physics',
          'DOJoing': '2015-04-01',
          'TIsPresent': 'Y',
          'TCat': 'Principal',
        },
        {
          'TeacherID': 2,
          'TName': 'Rehana Shaheen',
          'TFName': 'Fiaz Muhammad',
          'TCNIC': '38302-2222222-2',
          'TContactNo1': '03332222222',
          'TSubject': 'Urdu',
          'DOJoing': '2012-08-01',
          'TIsPresent': 'Y',
          'TCat': 'Teacher',
        },
        {
          'TeacherID': 3,
          'TName': 'Saima Naz',
          'TFName': 'Muhammad Tariq',
          'TCNIC': '38302-3333333-3',
          'TContactNo1': '03063333333',
          'TSubject': 'Mathematics',
          'DOJoing': '2014-09-04',
          'TIsPresent': 'Y',
          'TCat': 'Teacher',
        },
        {
          'TeacherID': 4,
          'TName': 'Yasmeen Akhtar',
          'TFName': 'Muhammad Anwar',
          'TCNIC': '38302-4444444-4',
          'TContactNo1': '0459235794',
          'TSubject': 'English',
          'DOJoing': '2011-02-01',
          'TIsPresent': 'Y',
          'TCat': 'Teacher',
        },
        {
          'TeacherID': 5,
          'TName': 'Akram Ali',
          'TFName': 'Ghulam Rasool',
          'TCNIC': '38302-5555555-5',
          'TContactNo1': '03335555555',
          'TSubject': 'Computer Science',
          'DOJoing': '2016-03-15',
          'TIsPresent': 'Y',
          'TCat': 'Staff',
        },
      ];

      for (final teacher in teachers) {
        await txn.insert(
          'Teachers',
          teacher,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 4. Stu_Reg (10 rows in Class 10, ClassID=13)
      const students = [
        {
          'Stu_RegID': 4411,
          'NameFirst': 'Muhammad Ali',
          'NameLast': 'Khan',
          'DOB': '2002-04-12',
          'F_Name': 'Khan Muhammad',
          'CNIC_No': '38302-1234567-1',
          'Sex': 'Male',
          'Mobile1': '03001234567',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4412,
          'NameFirst': 'Zainab',
          'NameLast': 'Ahmed',
          'DOB': '2002-06-20',
          'F_Name': 'Ahmed Hassan',
          'CNIC_No': '38302-2345678-2',
          'Sex': 'Female',
          'Mobile1': '03002345678',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4413,
          'NameFirst': 'Bilal',
          'NameLast': 'Hussain',
          'DOB': '2002-03-05',
          'F_Name': 'Hussain Shah',
          'CNIC_No': '38302-3456789-3',
          'Sex': 'Male',
          'Mobile1': '03003456789',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4414,
          'NameFirst': 'Fatima',
          'NameLast': 'Zahra',
          'DOB': '2002-07-18',
          'F_Name': 'Tariq Mehmood',
          'CNIC_No': '38302-4567890-4',
          'Sex': 'Female',
          'Mobile1': '03004567890',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4415,
          'NameFirst': 'Usman',
          'NameLast': 'Tariq',
          'DOB': '2002-11-22',
          'F_Name': 'Tariq Mehmood',
          'CNIC_No': '38302-4567890-4',
          'Sex': 'Male',
          'Mobile1': '03004567890',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4416,
          'NameFirst': 'Hamza',
          'NameLast': 'Nadeem',
          'DOB': '2002-09-14',
          'F_Name': 'Nadeem Akhtar',
          'CNIC_No': '38302-5678901-5',
          'Sex': 'Male',
          'Mobile1': '03005678901',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4417,
          'NameFirst': 'Ayesha',
          'NameLast': 'Ramzan',
          'DOB': '2002-01-08',
          'F_Name': 'Muhammad Ramzan',
          'CNIC_No': '38302-6789012-6',
          'Sex': 'Female',
          'Mobile1': '03006789012',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4418,
          'NameFirst': 'Ahmed',
          'NameLast': 'Raza',
          'DOB': '2002-12-30',
          'F_Name': 'Farooq Raza',
          'CNIC_No': '38302-7890123-7',
          'Sex': 'Male',
          'Mobile1': '03007890123',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4419,
          'NameFirst': 'Sana',
          'NameLast': 'Iqbal',
          'DOB': '2002-05-25',
          'F_Name': 'Iqbal Hussain',
          'CNIC_No': '38302-8901234-8',
          'Sex': 'Female',
          'Mobile1': '03008901234',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
        {
          'Stu_RegID': 4420,
          'NameFirst': 'Hassan',
          'NameLast': 'Akbar',
          'DOB': '2002-10-10',
          'F_Name': 'Akbar Shah',
          'CNIC_No': '38302-9012345-9',
          'Sex': 'Male',
          'Mobile1': '03009012345',
          'AdmClass': 13,
          'DOAdmission': '2024-08-15',
          'FullDiscount': 0,
        },
      ];

      for (final student in students) {
        await txn.insert(
          'Stu_Reg',
          student,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 5. Student_Class (10 rows — enroll 10 students into Class 10-A, ClassSecID=25)
      const studentClasses = [
        {
          'Stu_RegID': 4411,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 1,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4412,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 2,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4413,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 3,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4414,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 4,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4415,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 5,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4416,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 6,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4417,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 7,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4418,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 8,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4419,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 9,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
        {
          'Stu_RegID': 4420,
          'ClassID': 13,
          'ClassSecID': 25,
          'ClassRollNo': 10,
          'SessionYr': '2017-2018',
          'Present': 1,
          'VGen': 'Y',
        },
      ];

      for (final sc in studentClasses) {
        await txn.insert(
          'Student_Class',
          sc,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 6. BankInfo (1 default row for fee collection)
      await txn.insert('BankInfo', {
        'BankInfoID': 1,
        'BankName': 'Askari Bank',
        'Address': 'Ballo Khel Road, Mianwali',
        'Branch': 'Ballo Khel Road',
        'AcctNo': '4528',
        'AcctTitle': "Ailyan's Higher Secondary School",
        'AcctType': 'Current',
        'AcctStatus': 1,
        'BankDefault': 'Y',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // 7. VoucharMas (15 rows: 10 October 2017 + 5 September 2017)
      const vouchers = [
        // October 2017 (6 paid, 4 unpaid)
        {
          'VoucherMasID': '1710-4411',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'Y',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4412',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4412,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'Y',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4413',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4413,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'Y',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4414',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4414,
          'ClassID': 13,
          'SubTotal': 3300,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4415',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4415,
          'ClassID': 13,
          'SubTotal': 3300,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4416',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4416,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'Y',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4417',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4417,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4418',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4418,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'Y',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4419',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4419,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1710-4420',
          'VDate': '2017-10-01',
          'Student_Class_StuRegID': 4420,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'October 2017',
          'Discount': 0,
          'DueDate': '2017-10-10',
          'IsPaid': 'Y',
          'SessionYr': '2017-2018',
        },

        // September 2017 (5 vouchers: all unpaid arrears)
        {
          'VoucherMasID': '1709-4411',
          'VDate': '2017-09-01',
          'Student_Class_StuRegID': 4411,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'September 2017',
          'Discount': 0,
          'DueDate': '2017-09-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1709-4412',
          'VDate': '2017-09-01',
          'Student_Class_StuRegID': 4412,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'September 2017',
          'Discount': 0,
          'DueDate': '2017-09-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1709-4414',
          'VDate': '2017-09-01',
          'Student_Class_StuRegID': 4414,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'September 2017',
          'Discount': 0,
          'DueDate': '2017-09-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1709-4415',
          'VDate': '2017-09-01',
          'Student_Class_StuRegID': 4415,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'September 2017',
          'Discount': 0,
          'DueDate': '2017-09-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
        {
          'VoucherMasID': '1709-4417',
          'VDate': '2017-09-01',
          'Student_Class_StuRegID': 4417,
          'ClassID': 13,
          'SubTotal': 1800,
          'ForMonth': 'September 2017',
          'Discount': 0,
          'DueDate': '2017-09-10',
          'IsPaid': 'N',
          'SessionYr': '2017-2018',
        },
      ];

      for (final v in vouchers) {
        await txn.insert(
          'VoucharMas',
          v,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 8. VoucharDet (27 rows: 22 October + 5 September)
      const voucherDetails = [
        // October 2017 items
        {
          'VoucharDetID': 1,
          'VoucharMasID': '1710-4411',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 2,
          'VoucharMasID': '1710-4411',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 3,
          'VoucharMasID': '1710-4412',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 4,
          'VoucharMasID': '1710-4412',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 5,
          'VoucharMasID': '1710-4413',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 6,
          'VoucharMasID': '1710-4413',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 7,
          'VoucharMasID': '1710-4414',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 8,
          'VoucharMasID': '1710-4414',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 9,
          'VoucharMasID': '1710-4414',
          'feeParameterID': 4,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 10,
          'VoucharMasID': '1710-4415',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 11,
          'VoucharMasID': '1710-4415',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 12,
          'VoucharMasID': '1710-4415',
          'feeParameterID': 4,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 13,
          'VoucharMasID': '1710-4416',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 14,
          'VoucharMasID': '1710-4416',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 15,
          'VoucharMasID': '1710-4417',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 16,
          'VoucharMasID': '1710-4417',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 17,
          'VoucharMasID': '1710-4418',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 18,
          'VoucharMasID': '1710-4418',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 19,
          'VoucharMasID': '1710-4419',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 20,
          'VoucharMasID': '1710-4419',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },
        {
          'VoucharDetID': 21,
          'VoucharMasID': '1710-4420',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 22,
          'VoucharMasID': '1710-4420',
          'feeParameterID': 3,
          'Amount': 300,
          'Discount': 0,
        },

        // September 2017 items
        {
          'VoucharDetID': 23,
          'VoucharMasID': '1709-4411',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 24,
          'VoucharMasID': '1709-4412',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 25,
          'VoucharMasID': '1709-4414',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 26,
          'VoucharMasID': '1709-4415',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
        {
          'VoucharDetID': 27,
          'VoucharMasID': '1709-4417',
          'feeParameterID': 2,
          'Amount': 1500,
          'Discount': 0,
        },
      ];

      for (final vd in voucherDetails) {
        await txn.insert(
          'VoucharDet',
          vd,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 9. FeeTransaction (6 rows)
      const transactions = [
        {
          'FeeTransID': 1,
          'BankID': 1,
          'SubmissionDate': '2017-10-20 09:14:00',
          'VoucharNo': '1710-4411',
          'TotalAmount': 1800,
          'PaidAmount': 1800,
          'Detail': 'Cash',
        },
        {
          'FeeTransID': 2,
          'BankID': 1,
          'SubmissionDate': '2017-10-20 09:22:00',
          'VoucharNo': '1710-4412',
          'TotalAmount': 1800,
          'PaidAmount': 1800,
          'Detail': 'Cash',
        },
        {
          'FeeTransID': 3,
          'BankID': 1,
          'SubmissionDate': '2017-10-20 09:35:00',
          'VoucharNo': '1710-4413',
          'TotalAmount': 1800,
          'PaidAmount': 1800,
          'Detail': 'Cash',
        },
        {
          'FeeTransID': 4,
          'BankID': 1,
          'SubmissionDate': '2017-10-20 10:15:00',
          'VoucharNo': '1710-4416',
          'TotalAmount': 1800,
          'PaidAmount': 1800,
          'Detail': 'Cash',
        },
        {
          'FeeTransID': 5,
          'BankID': 1,
          'SubmissionDate': '2017-10-20 10:30:00',
          'VoucharNo': '1710-4418',
          'TotalAmount': 1800,
          'PaidAmount': 1800,
          'Detail': 'Bank HBL',
        },
        {
          'FeeTransID': 6,
          'BankID': 1,
          'SubmissionDate': '2017-10-20 11:05:00',
          'VoucharNo': '1710-4420',
          'TotalAmount': 1800,
          'PaidAmount': 1800,
          'Detail': 'Bank HBL',
        },
      ];

      for (final tx in transactions) {
        await txn.insert(
          'FeeTransaction',
          tx,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Seeds 16 canonical fee parameters from legacy SDB_Ailyans.mdb catalog.
  static Future<void> _seedFeeParameters(Database db) async {
    await db.transaction((txn) async {
      const feeParams = [
        {'FeeParamID': 1, 'ParamDesciption': 'Admission Fee '},
        {'FeeParamID': 2, 'ParamDesciption': 'Tuition Fee '},
        {'FeeParamID': 3, 'ParamDesciption': 'Exam Fee'},
        {'FeeParamID': 4, 'ParamDesciption': 'Arears'},
        {'FeeParamID': 5, 'ParamDesciption': 'Paid Amount'},
        {'FeeParamID': 6, 'ParamDesciption': 'Arears'},
        {'FeeParamID': 7, 'ParamDesciption': 'Annual Cgarges'},
        {'FeeParamID': 8, 'ParamDesciption': 'Late Fee'},
        {'FeeParamID': 9, 'ParamDesciption': 'Balance'},
        {'FeeParamID': 10, 'ParamDesciption': 'Balance'},
        {'FeeParamID': 11, 'ParamDesciption': 'Examination Fee'},
        {'FeeParamID': 12, 'ParamDesciption': 'adjustment'},
        {'FeeParamID': 13, 'ParamDesciption': 'Late Fee'},
        {'FeeParamID': 14, 'ParamDesciption': 'SLC.Fee/'},
        {'FeeParamID': 15, 'ParamDesciption': 'Paid Amount'},
        {'FeeParamID': 16, 'ParamDesciption': 'Annually Charges'},
      ];

      for (final param in feeParams) {
        await txn.insert(
          'FeeParameters',
          param,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Seeds today's attendance for Class 10-A (AttMas + 10 AttDet rows).
  static Future<void> _seedAttendanceData(Database db) async {
    await db.transaction((txn) async {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final attDate = '$todayStr 08:00:00';

      // 1. AttMas (1 master record for Class 10-A)
      await txn.insert('AttMas', {
        'AttMasID': 1,
        'TeacherID': 1,
        'ClassID': 13,
        'ClassSecID': 25,
        'AttDate': attDate,
        'StudySessionYr': '2017-2018',
        'Remarks': '',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // 2. AttDet (10 student attendance detail records: 8 Present, 1 Absent, 1 Leave)
      const attendanceRecords = [
        {'AttDetID': 1, 'Stu_RegID': 4411, 'AttStatus': 'Present'},
        {'AttDetID': 2, 'Stu_RegID': 4412, 'AttStatus': 'Present'},
        {'AttDetID': 3, 'Stu_RegID': 4413, 'AttStatus': 'Present'},
        {'AttDetID': 4, 'Stu_RegID': 4414, 'AttStatus': 'Present'},
        {'AttDetID': 5, 'Stu_RegID': 4415, 'AttStatus': 'Present'},
        {'AttDetID': 6, 'Stu_RegID': 4416, 'AttStatus': 'Absent'},
        {'AttDetID': 7, 'Stu_RegID': 4417, 'AttStatus': 'Present'},
        {'AttDetID': 8, 'Stu_RegID': 4418, 'AttStatus': 'Present'},
        {'AttDetID': 9, 'Stu_RegID': 4419, 'AttStatus': 'Leave'},
        {'AttDetID': 10, 'Stu_RegID': 4420, 'AttStatus': 'Present'},
      ];

      for (final att in attendanceRecords) {
        await txn.insert('AttDet', {
          'AttDetID': att['AttDetID'],
          'AttMasID': 1,
          'Stu_RegID': att['Stu_RegID'],
          'AttStatus': att['AttStatus'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Seeds Cls_Param_Fee tariff table for batch billing (idempotent).
  static Future<void> seedFeeTariffsIfEmpty(Database db) async {
    final tuples = <({String className, int feeParamId, double fee})>[
      (className: 'Class 10', feeParamId: 2, fee: 1500.0),
      (className: 'Class 10', feeParamId: 3, fee: 300.0),
      (className: 'Class 10', feeParamId: 7, fee: 120.0),
      (className: 'Class 5', feeParamId: 2, fee: 1200.0),
      (className: 'Class 5', feeParamId: 3, fee: 250.0),
      (className: 'Class 5', feeParamId: 7, fee: 100.0),
      (className: 'Class 3', feeParamId: 2, fee: 1000.0),
      (className: 'Class 3', feeParamId: 3, fee: 200.0),
      (className: 'Class 3', feeParamId: 7, fee: 80.0),
    ];

    const feeYr = '2017-2018';

    for (final t in tuples) {
      final clsRows = await db.rawQuery(
        'SELECT ClassID FROM Class WHERE CName = ? LIMIT 1',
        [t.className],
      );
      if (clsRows.isEmpty) continue; // class not seeded, skip silently
      final classId = clsRows.first['ClassID'] as int;

      final existing = await db.rawQuery(
        'SELECT Cls_Param_Fee_ID FROM Cls_Param_Fee '
        'WHERE ClassID = ? AND FeeParamID = ? AND FeeYr = ? LIMIT 1',
        [classId, t.feeParamId, feeYr],
      );
      if (existing.isNotEmpty) continue; // idempotent

      final idRows = await db.rawQuery(
        'SELECT COALESCE(MAX(Cls_Param_Fee_ID), 0) + 1 AS nextId '
        'FROM Cls_Param_Fee',
      );
      final nextId = (idRows.first['nextId'] as int?) ?? 1;

      await db.insert('Cls_Param_Fee', {
        'Cls_Param_Fee_ID': nextId,
        'ClassID': classId,
        'FeeParamID': t.feeParamId,
        'FeeYr': feeYr,
        'Fee': t.fee,
      });
    }
  }
}
