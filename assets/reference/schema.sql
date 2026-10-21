-- ==========================================================
-- Complete SQLite Schema for Ailyans School Automation System
-- Source: SDB_Ailyans.mdb
-- Active Tables: 49
-- Active Indexes: 78
-- ==========================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------
-- 1. TABLE DEFINITIONS (49 ACTIVE TABLES)
-- ----------------------------------------------------------

-- Table: `AccObj`
CREATE TABLE IF NOT EXISTS `AccObj`
 (
	`ObjID`			INTEGER, 
	`ObjName`			TEXT, 
	`DisplayName`			TEXT
	, PRIMARY KEY (`ObjID`)
);

-- Table: `AccRhts`
CREATE TABLE IF NOT EXISTS `AccRhts`
 (
	`UID`			INTEGER, 
	`ObjID`			INTEGER
);

-- Table: `AttDet`
CREATE TABLE IF NOT EXISTS `AttDet`
 (
	`AttDetID`			INTEGER, 
	`AttMasID`			INTEGER NOT NULL, 
	`Stu_RegID`			INTEGER NOT NULL, 
	`AttStatus`			TEXT NOT NULL, 
	`InTime`			TEXT, 
	`OutTime`			TEXT, 
	`AttAppcation`			TEXT, 
	`LeaveRequestedBy`			TEXT, 
	`LFrom`			TEXT, 
	`LTill`			TEXT, 
	`Reason`			TEXT, 
	`IsApproved`			TEXT, 
	`AttRemarks`			TEXT
	, PRIMARY KEY (`AttMasID`, `Stu_RegID`)
);

-- Table: `AttMas`
CREATE TABLE IF NOT EXISTS `AttMas`
 (
	`AttMasID`			INTEGER, 
	`TeacherID`			INTEGER, 
	`ClassID`			INTEGER NOT NULL, 
	`ClassSecID`			INTEGER NOT NULL, 
	`AttDate`			TEXT, 
	`StudySessionYr`			TEXT, 
	`Remarks`			TEXT
	, PRIMARY KEY (`ClassID`, `ClassSecID`, `AttDate`)
);

-- Table: `BankInfo`
CREATE TABLE IF NOT EXISTS `BankInfo`
 (
	`BankInfoID`			INTEGER, 
	`BankName`			TEXT NOT NULL, 
	`Address`			TEXT, 
	`Branch`			TEXT, 
	`AcctNo`			TEXT NOT NULL, 
	`AcctTitle`			TEXT, 
	`AcctType`			TEXT, 
	`AcctStatus`			INTEGER NOT NULL, 
	`BankDefault`			TEXT
	, PRIMARY KEY (`BankInfoID`)
);

-- Table: `BioSett`
CREATE TABLE IF NOT EXISTS `BioSett`
 (
	`BioSettID`			INTEGER, 
	`InSMS`			TEXT, 
	`OutSMS`			TEXT, 
	`LateSMS`			TEXT, 
	`AbsentSMS`			TEXT, 
	`EmpInSMS`			TEXT, 
	`EmpOutSMS`			TEXT, 
	`AutoAbsentMark`			TEXT, 
	`InMessage`			TEXT, 
	`OutMessage`			TEXT, 
	`LateInMessage`			TEXT, 
	`AbsentMessage`			TEXT, 
	`StartTime`			TEXT, 
	`OffTime`			TEXT, 
	`LateConsiTime`			TEXT, 
	`AbsentConsiTime`			TEXT, 
	`EmpSentToNumner`			TEXT, 
	`AbsentMarkAuto`			TEXT, 
	`BrInfo`			TEXT
	, PRIMARY KEY (`BioSettID`)
);

-- Table: `BioTemp`
CREATE TABLE IF NOT EXISTS `BioTemp`
 (
	`ID`			INTEGER, 
	`DTStamp`			TEXT
	, PRIMARY KEY (`ID`, `DTStamp`)
);

-- Table: `BookImg`
CREATE TABLE IF NOT EXISTS `BookImg`
 (
	`BkID`			INTEGER, 
	`BookTitle`			BLOB
	, PRIMARY KEY (`BkID`)
);

-- Table: `Books`
CREATE TABLE IF NOT EXISTS `Books`
 (
	`BookID`			INTEGER, 
	`BookCatSubj`			INTEGER, 
	`BookName`			TEXT, 
	`BAuthor`			TEXT, 
	`Pages`			INTEGER, 
	`PulishedBy`			TEXT, 
	`PublishedYr`			INTEGER, 
	`BookPrice`			INTEGER, 
	`Detail`			TEXT
	, PRIMARY KEY (`BookID`)
);

-- Table: `Class`
CREATE TABLE IF NOT EXISTS `Class`
 (
	`ClassID`			INTEGER, 
	`CName`			TEXT
	, PRIMARY KEY (`ClassID`)
);

-- Table: `Class_Subj`
-- DEAD TABLE: Not referenced in binary SQL, preserved for historical data
CREATE TABLE IF NOT EXISTS `Class_Subj`
 (
	`ClasSubjID`			INTEGER, 
	`ClassID`			INTEGER, 
	`SubjID`			INTEGER, 
	`Detail`			TEXT
	, PRIMARY KEY (`ClasSubjID`)
);

-- Table: `ClassSec`
CREATE TABLE IF NOT EXISTS `ClassSec`
 (
	`ClassSecID`			INTEGER, 
	`ClassID`			INTEGER, 
	`SecName`			TEXT, 
	`SecTeacher`			INTEGER, 
	`SecProctor`			INTEGER, 
	`RoomNo`			TEXT, 
	`Remarks`			TEXT
	, PRIMARY KEY (`ClassSecID`)
);

-- Table: `Cls_Param_Fee`
CREATE TABLE IF NOT EXISTS `Cls_Param_Fee`
 (
	`Cls_Param_Fee_ID`			INTEGER, 
	`ClassID`			INTEGER, 
	`FeeParamID`			INTEGER, 
	`FeeYr`			TEXT NOT NULL, 
	`Fee`			REAL
	, PRIMARY KEY (`ClassID`, `FeeParamID`, `FeeYr`)
);

-- Table: `ContactCat`
CREATE TABLE IF NOT EXISTS `ContactCat`
 (
	`ContactCatID`			INTEGER, 
	`CatName`			TEXT NOT NULL, 
	`Remarks`			TEXT
	, PRIMARY KEY (`ContactCatID`)
);

-- Table: `Contacts`
CREATE TABLE IF NOT EXISTS `Contacts`
 (
	`ContactID`			INTEGER, 
	`ContactCatID`			INTEGER, 
	`ContactName`			TEXT, 
	`Detail`			TEXT, 
	`CNumber1`			TEXT, 
	`Cnumber2`			TEXT, 
	`EmergencyNumber`			TEXT
	, PRIMARY KEY (`ContactID`)
);

-- Table: `ExamInfo`
CREATE TABLE IF NOT EXISTS `ExamInfo`
 (
	`ExamInfoID`			INTEGER, 
	`ExTermID`			INTEGER NOT NULL, 
	`SessionYR`			TEXT, 
	`StartDate`			TEXT, 
	`EndDate`			TEXT, 
	`ResultDate`			TEXT, 
	`ExamSupervisorID`			INTEGER, 
	`Location`			TEXT, 
	`Detail`			TEXT
	, PRIMARY KEY (`ExTermID`, `SessionYR`)
);

-- Table: `ExamMas`
CREATE TABLE IF NOT EXISTS `ExamMas`
 (
	`ExamMasID`			INTEGER, 
	`ExamInfoID`			INTEGER, 
	`ExTermID`			INTEGER, 
	`ClassID`			INTEGER, 
	`ClassSecID`			INTEGER, 
	`Stu_RegID`			INTEGER, 
	`TeacherID`			INTEGER, 
	`Detail`			TEXT, 
	`SessionYr`			TEXT
	, PRIMARY KEY (`ExamInfoID`, `Stu_RegID`)
);

-- Table: `ExamTerm`
CREATE TABLE IF NOT EXISTS `ExamTerm`
 (
	`ExTermID`			INTEGER, 
	`TermName`			TEXT, 
	`TermRemarks`			TEXT
	, PRIMARY KEY (`ExTermID`)
);

-- Table: `ExamTop`
CREATE TABLE IF NOT EXISTS `ExamTop`
 (
	`TopID`			INTEGER, 
	`ExamID`			INTEGER, 
	`ClassID`			INTEGER, 
	`ClassSecID`			INTEGER, 
	`Stu_RegID`			INTEGER, 
	`RollNo`			INTEGER, 
	`TotalMark`			INTEGER, 
	`ObtainedMarks`			INTEGER, 
	`ClassPosition`			INTEGER
	, PRIMARY KEY (`TopID`)
);

-- Table: `ExGrade`
CREATE TABLE IF NOT EXISTS `ExGrade`
 (
	`ExGradID`			INTEGER, 
	`CalssID`			INTEGER, 
	`Grad`			TEXT, 
	`GradMinMarks`			INTEGER, 
	`GradMaxMarks`			INTEGER, 
	`Remarks`			TEXT
	, PRIMARY KEY (`ExGradID`)
);

-- Table: `FeeParameters`
CREATE TABLE IF NOT EXISTS `FeeParameters`
 (
	`FeeParamID`			INTEGER, 
	`ParamDesciption`			TEXT
	, PRIMARY KEY (`FeeParamID`)
);

-- Table: `FeeTransaction`
CREATE TABLE IF NOT EXISTS `FeeTransaction`
 (
	`FeeTransID`			INTEGER, 
	`BankID`			INTEGER, 
	`SubmissionDate`			TEXT, 
	`VoucharNo`			TEXT, 
	`TotalAmount`			INTEGER, 
	`PaidAmount`			INTEGER, 
	`Detail`			TEXT
	, PRIMARY KEY (`FeeTransID`)
);

-- Table: `InstBranch`
CREATE TABLE IF NOT EXISTS `InstBranch`
 (
	`BrnachID`			INTEGER, 
	`InstituteID`			INTEGER, 
	`BranchName`			TEXT, 
	`BranchAddress`			TEXT, 
	`BrLogo`			BLOB, 
	`BrPhone`			TEXT, 
	`BrFaxNo`			TEXT, 
	`BrEmailAddress`			TEXT, 
	`BrWebsite`			TEXT, 
	`BrPrincipal`			TEXT, 
	`BrContactPerson`			TEXT, 
	`Mobile`			TEXT, 
	`Remarks`			TEXT, 
	`SecPd`			TEXT
	, PRIMARY KEY (`BrnachID`)
);

-- Table: `InstInfo`
CREATE TABLE IF NOT EXISTS `InstInfo`
 (
	`InstituteID`			INTEGER, 
	`InstName`			TEXT, 
	`Address`			TEXT, 
	`Logo`			BLOB, 
	`OfficePhone`			TEXT, 
	`FaxNo`			TEXT, 
	`EmailAddress`			TEXT, 
	`Website`			TEXT, 
	`Phone`			TEXT, 
	`Owner`			TEXT, 
	`ContactPerson`			TEXT, 
	`Mobile`			TEXT, 
	`Remarks`			TEXT
	, PRIMARY KEY (`InstituteID`)
);

-- Table: `Kalendar`
-- DEAD TABLE: Not referenced in binary SQL, preserved for historical data
CREATE TABLE IF NOT EXISTS `Kalendar`
 (
	`KalendarID`			INTEGER, 
	`KalDate`			TEXT, 
	`Commitment`			TEXT, 
	`Pri`			INTEGER
	, PRIMARY KEY (`KalendarID`)
);

-- Table: `Paste Errors`
-- DEAD TABLE: Not referenced in binary SQL, preserved for historical data
CREATE TABLE IF NOT EXISTS `Paste Errors`
 (
	`ObjName`			TEXT, 
	`DisplayName`			TEXT
);

-- Table: `SMSDraft`
CREATE TABLE IF NOT EXISTS `SMSDraft`
 (
	`MsgID`			INTEGER, 
	`MsgDraft1`			TEXT NOT NULL, 
	`MsgDraft2`			TEXT
	, PRIMARY KEY (`MsgID`)
);

-- Table: `SMSSet`
CREATE TABLE IF NOT EXISTS `SMSSet`
 (
	`SMSSetID`			INTEGER, 
	`SMSSetIP`			TEXT, 
	`SMSSetPrt`			TEXT, 
	`SMSSetUsr`			TEXT, 
	`SMSSetPwd`			TEXT
	, PRIMARY KEY (`SMSSetID`)
);

-- Table: `Stu_Reg`
CREATE TABLE IF NOT EXISTS `Stu_Reg`
 (
	`Stu_RegID`			INTEGER NOT NULL, 
	`NameFirst`			TEXT NOT NULL, 
	`NameMiddle`			TEXT, 
	`NameLast`			TEXT, 
	`DOB`			TEXT, 
	`B_Form_No`			TEXT, 
	`F_Name`			TEXT, 
	`CNIC_No`			TEXT, 
	`Occupation`			TEXT, 
	`P_Address`			TEXT, 
	`T_Address`			TEXT, 
	`Phone_Office`			TEXT, 
	`Phone_Res`			TEXT, 
	`Mobile1`			TEXT, 
	`Mobile2`			TEXT, 
	`Religion`			TEXT, 
	`P_School`			TEXT, 
	`SLCertificate`			TEXT, 
	`P_Class`			TEXT, 
	`AdmInClass`			INTEGER, 
	`AdmClass`			INTEGER, 
	`DOAdmission`			TEXT, 
	`DocsDetail`			TEXT, 
	`Discount`			REAL, 
	`EmerContName`			TEXT, 
	`EmerContMobile`			TEXT, 
	`OfficeFile`			TEXT, 
	`Remarls`			TEXT, 
	`VMDiscount`			INTEGER, 
	`FullDiscount`			INTEGER NOT NULL, 
	`Nationality`			TEXT, 
	`Sex`			TEXT, 
	`photo_path`			TEXT
	, PRIMARY KEY (`Stu_RegID`)
);

-- Table: `StuAdv`
CREATE TABLE IF NOT EXISTS `StuAdv`
 (
	`StuAdvID`			INTEGER, 
	`StuRegID`			INTEGER, 
	`AdvAmount`			INTEGER, 
	`MOP`			TEXT, 
	`Date`			TEXT, 
	`DepositedBy`			TEXT, 
	`Detail`			TEXT
	, PRIMARY KEY (`StuAdvID`)
);

-- Table: `Student_Class`
CREATE TABLE IF NOT EXISTS `Student_Class`
 (
	`Stu_RegID`			INTEGER, 
	`ClassID`			INTEGER, 
	`ClassSecID`			INTEGER, 
	`ClassRollNo`			INTEGER, 
	`SessionYr`			TEXT NOT NULL, 
	`Present`			INTEGER NOT NULL, 
	`PassingMarks`			INTEGER, 
	`PromotionDate`			TEXT, 
	`VGen`			TEXT
	, PRIMARY KEY (`Stu_RegID`, `ClassID`, `SessionYr`)
);

-- Table: `Subj_Class`
CREATE TABLE IF NOT EXISTS `Subj_Class`
 (
	`Subj_ClsID`			INTEGER, 
	`SubjID`			INTEGER, 
	`ClassID`			INTEGER, 
	`TeacherID`			INTEGER, 
	`TotalMarks`			INTEGER, 
	`TotalPracticalMarks`			INTEGER
	, PRIMARY KEY (`SubjID`, `ClassID`)
);

-- Table: `Subject`
CREATE TABLE IF NOT EXISTS `Subject`
 (
	`SubjID`			INTEGER, 
	`SubjName`			TEXT, 
	`SubjDetail`			TEXT
	, PRIMARY KEY (`SubjID`)
);

-- Table: `TAtt`
CREATE TABLE IF NOT EXISTS `TAtt`
 (
	`TAttID`			INTEGER, 
	`TeacherID`			INTEGER NOT NULL, 
	`AttDate`			TEXT, 
	`Status`			TEXT, 
	`InTime`			TEXT, 
	`OutTime`			TEXT, 
	`LeaveReason`			TEXT, 
	`Remarks`			TEXT, 
	`SessionYr`			TEXT
	, PRIMARY KEY (`TeacherID`, `AttDate`)
);

-- Table: `Teachers`
CREATE TABLE IF NOT EXISTS `Teachers`
 (
	`TeacherID`			INTEGER, 
	`TName`			TEXT NOT NULL, 
	`TFName`			TEXT, 
	`TCNIC`			TEXT NOT NULL, 
	`DOB`			TEXT, 
	`TContactNo1`			TEXT NOT NULL, 
	`TContactNo2`			TEXT, 
	`TAddress`			TEXT, 
	`Domicile`			TEXT, 
	`TSubject`			TEXT, 
	`DOJoing`			TEXT, 
	`Detail`			TEXT, 
	`TIsPresent`			TEXT NOT NULL, 
	`TEmergencyContactName`			TEXT, 
	`TEmergencyContactNo`			TEXT, 
	`TDoLeft`			TEXT, 
	`TQualification`			TEXT, 
	`TProfessional`			TEXT, 
	`TCertificate`			TEXT, 
	`TFiledOfExperty`			TEXT, 
	`TExperience`			TEXT, 
	`TAnySpeciality`			TEXT, 
	`OfficeFile`			TEXT, 
	`TCat`			TEXT, 
	`TBioSer`			REAL, 
	`AttSMSCont`			TEXT
	, PRIMARY KEY (`TeacherID`)
);

-- Table: `TEmp_Lvl`
CREATE TABLE IF NOT EXISTS `TEmp_Lvl`
 (
	`TSalLvlID`			INTEGER, 
	`TeacherID`			INTEGER
	, PRIMARY KEY (`TeacherID`)
);

-- Table: `TempPromo`
CREATE TABLE IF NOT EXISTS `TempPromo`
 (
	`TempPromoID`			INTEGER, 
	`Stu_RegID`			INTEGER, 
	`Name`			TEXT, 
	`Marks`			INTEGER, 
	`V`			TEXT
	, PRIMARY KEY (`TempPromoID`)
);

-- Table: `TSalDet`
CREATE TABLE IF NOT EXISTS `TSalDet`
 (
	`TSalDetSer`			INTEGER, 
	`TSalMasID`			TEXT, 
	`Detail`			TEXT, 
	`Amount`			INTEGER, 
	`Remarks`			TEXT
	, PRIMARY KEY (`TSalMasID`, `Detail`)
);

-- Table: `TSalInc`
-- DEAD TABLE: Not referenced in binary SQL, preserved for historical data
CREATE TABLE IF NOT EXISTS `TSalInc`
 (
	`TSalIncID`			INTEGER, 
	`IncDate`			TEXT, 
	`IncDetail`			TEXT, 
	`Amount`			INTEGER, 
	`EmpIncNumber`			INTEGER, 
	`EmpID`			INTEGER, 
	`PerLeaveCharge`			INTEGER, 
	`SalYear`			TEXT, 
	`TSalLvlID`			INTEGER
	, PRIMARY KEY (`EmpIncNumber`, `EmpID`)
);

-- Table: `TSalLvl`
CREATE TABLE IF NOT EXISTS `TSalLvl`
 (
	`SalLvl`			INTEGER, 
	`LvlDetail`			TEXT, 
	`AllowedLeaves`			INTEGER, 
	`PerLeaveDeduct`			INTEGER
	, PRIMARY KEY (`SalLvl`)
);

-- Table: `TSalLvlAmount`
CREATE TABLE IF NOT EXISTS `TSalLvlAmount`
 (
	`T_SalTD`			INTEGER, 
	`SalLvl`			INTEGER, 
	`SalParamID`			INTEGER, 
	`Amount`			INTEGER, 
	`SalYear`			TEXT, 
	`Remarks`			TEXT
	, PRIMARY KEY (`SalLvl`, `SalParamID`, `SalYear`)
);

-- Table: `TSalMas`
CREATE TABLE IF NOT EXISTS `TSalMas`
 (
	`TSalMasID`			TEXT, 
	`TeacherID`			INTEGER, 
	`DisbursDate`			TEXT, 
	`SalMonth`			TEXT, 
	`PaidAmt`			INTEGER, 
	`TDeductions`			INTEGER, 
	`Detail`			TEXT, 
	`IsPaid`			TEXT, 
	`PaidDate`			TEXT
	, PRIMARY KEY (`TeacherID`, `SalMonth`)
);

-- Table: `Users`
CREATE TABLE IF NOT EXISTS `Users`
 (
	`ID`			INTEGER, 
	`Name`			TEXT, 
	`Desig`			TEXT, 
	`CNIC`			TEXT, 
	`Pwd`			TEXT NOT NULL, 
	`Br`			TEXT, 
	`Address`			TEXT, 
	`Mobile1`			TEXT, 
	`Mobile2`			TEXT, 
	`UserLvl`			INTEGER, 
	`Remarks`			TEXT
	, PRIMARY KEY (`ID`)
);

-- Table: `VoucharDet`
CREATE TABLE IF NOT EXISTS `VoucharDet`
 (
	`VoucharDetID`			REAL, 
	`VoucharMasID`			TEXT, 
	`feeParameterID`			INTEGER, 
	`Amount`			REAL, 
	`Discount`			REAL
	, PRIMARY KEY (`VoucharDetID`, `VoucharMasID`, `feeParameterID`)
);

-- Table: `VoucharMas`
CREATE TABLE IF NOT EXISTS `VoucharMas`
 (
	`VoucherMasID`			TEXT, 
	`VDate`			TEXT, 
	`Student_Class_StuRegID`			INTEGER, 
	`SubTotal`			INTEGER, 
	`ForMonth`			TEXT, 
	`ClassID`			INTEGER, 
	`Remarks`			TEXT, 
	`Discount`			INTEGER, 
	`DueDate`			TEXT, 
	`IsPaid`			TEXT, 
	`SessionYr`			TEXT
);

-- Table: `ExamDet`
CREATE TABLE IF NOT EXISTS `ExamDet`
 (
	`ExDetID`			INTEGER, 
	`ExamInfoID`			INTEGER, 
	`ExamMasID`			INTEGER, 
	`SubjID`			INTEGER, 
	`ObtainedMarks`			INTEGER, 
	`TotalMarks`			INTEGER, 
	`ObtainedPracMarks`			INTEGER, 
	`TotalPracticalMarks`			INTEGER
	, PRIMARY KEY (`ExamMasID`, `SubjID`)
);

-- Table: `SchLeaving`
CREATE TABLE IF NOT EXISTS `SchLeaving`
 (
	`SLID`			INTEGER, 
	`StuRegID`			INTEGER NOT NULL, 
	`LeftDate`			TEXT, 
	`LeftClass`			INTEGER, 
	`Charactor`			TEXT, 
	`TermOfLeavign`			TEXT, 
	`SLCertificate`			INTEGER NOT NULL, 
	`Remarks`			TEXT
	, PRIMARY KEY (`StuRegID`)
);

-- Table: `TempPromoHistory`
CREATE TABLE IF NOT EXISTS `TempPromoHistory`
 (
	`ID`			INTEGER, 
	`FromSessionYr`			TEXT, 
	`FromClass`			TEXT, 
	`FromSection`			TEXT, 
	`ToSessionYr`			TEXT, 
	`ToClass`			TEXT, 
	`ToSection`			TEXT, 
	`Strenght`			INTEGER
	, PRIMARY KEY (`ID`)
);

-- Table: `TSalParam`
CREATE TABLE IF NOT EXISTS `TSalParam`
 (
	`SalParamID`			INTEGER, 
	`SalParam`			TEXT
	, PRIMARY KEY (`SalParamID`)
);

-- ----------------------------------------------------------
-- 2. INDEX DEFINITIONS
-- ----------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS `AttDet_AttandID_idx` ON `AttDet` (`AttDetID`);
CREATE INDEX IF NOT EXISTS `AttDet_AttMasID_idx` ON `AttDet` (`AttMasID`);
CREATE INDEX IF NOT EXISTS `AttDet_Stu_RegID_idx` ON `AttDet` (`Stu_RegID`);
CREATE UNIQUE INDEX IF NOT EXISTS `AttMas_AttandID_idx` ON `AttMas` (`AttMasID`);
CREATE INDEX IF NOT EXISTS `AttMas_AttDate_idx` ON `AttMas` (`AttDate`);
CREATE INDEX IF NOT EXISTS `AttMas_ClassID_idx` ON `AttMas` (`ClassID`);
CREATE INDEX IF NOT EXISTS `AttMas_ClassSecID_idx` ON `AttMas` (`ClassSecID`);
CREATE INDEX IF NOT EXISTS `AttMas_TeacherID_idx` ON `AttMas` (`TeacherID`);
CREATE INDEX IF NOT EXISTS `BioSett_BioSettID_idx` ON `BioSett` (`BioSettID`);
CREATE INDEX IF NOT EXISTS `Class_Subj_ClassID_idx` ON `Class_Subj` (`ClassID`);
CREATE INDEX IF NOT EXISTS `Class_Subj_SubjID_idx` ON `Class_Subj` (`SubjID`);
CREATE INDEX IF NOT EXISTS `ClassSec_ClassID_idx` ON `ClassSec` (`ClassID`);
CREATE INDEX IF NOT EXISTS `ClassSec_SecTeacher_idx` ON `ClassSec` (`SecTeacher`);
CREATE INDEX IF NOT EXISTS `Cls_Param_Fee_ClassID_idx` ON `Cls_Param_Fee` (`ClassID`);
CREATE INDEX IF NOT EXISTS `Cls_Param_Fee_Cls_Param_Fee_ID_idx` ON `Cls_Param_Fee` (`Cls_Param_Fee_ID`);
CREATE INDEX IF NOT EXISTS `Cls_Param_Fee_FeeParamID_idx` ON `Cls_Param_Fee` (`FeeParamID`);
CREATE INDEX IF NOT EXISTS `Contacts_ContactCatID_idx` ON `Contacts` (`ContactCatID`);
CREATE INDEX IF NOT EXISTS `ExamInfo_ExamInfoExamInfoID_idx` ON `ExamInfo` (`ExamInfoID`);
CREATE INDEX IF NOT EXISTS `ExamInfo_ExTermID_idx` ON `ExamInfo` (`ExTermID`);
CREATE INDEX IF NOT EXISTS `ExamMas_ClassID_idx` ON `ExamMas` (`ClassID`);
CREATE INDEX IF NOT EXISTS `ExamMas_ClassSecID_idx` ON `ExamMas` (`ClassSecID`);
CREATE INDEX IF NOT EXISTS `ExamMas_ExamInfoID_idx` ON `ExamMas` (`ExamInfoID`);
CREATE UNIQUE INDEX IF NOT EXISTS `ExamMas_ExamMasID_idx` ON `ExamMas` (`ExamMasID`);
CREATE INDEX IF NOT EXISTS `ExamMas_ExTermID_idx` ON `ExamMas` (`ExTermID`);
CREATE INDEX IF NOT EXISTS `ExamMas_SessionYr_idx` ON `ExamMas` (`SessionYr`);
CREATE INDEX IF NOT EXISTS `ExamMas_Stu_RegID_idx` ON `ExamMas` (`Stu_RegID`);
CREATE INDEX IF NOT EXISTS `ExamMas_TeacherID_idx` ON `ExamMas` (`TeacherID`);
CREATE INDEX IF NOT EXISTS `ExamTop_ClassID_idx` ON `ExamTop` (`ClassID`);
CREATE INDEX IF NOT EXISTS `ExamTop_ClassSecID_idx` ON `ExamTop` (`ClassSecID`);
CREATE INDEX IF NOT EXISTS `ExamTop_ExamID_idx` ON `ExamTop` (`ExamID`);
CREATE INDEX IF NOT EXISTS `ExamTop_Stu_RegID_idx` ON `ExamTop` (`Stu_RegID`);
CREATE INDEX IF NOT EXISTS `ExamTop_TopID_idx` ON `ExamTop` (`TopID`);
CREATE INDEX IF NOT EXISTS `ExGrade_CalssID_idx` ON `ExGrade` (`CalssID`);
CREATE INDEX IF NOT EXISTS `ExGrade_ExGradID_idx` ON `ExGrade` (`ExGradID`);
CREATE INDEX IF NOT EXISTS `FeeTransaction_BankID_idx` ON `FeeTransaction` (`BankID`);
CREATE INDEX IF NOT EXISTS `FeeTransaction_VoucharNo_idx` ON `FeeTransaction` (`VoucharNo`);
CREATE INDEX IF NOT EXISTS `Kalendar_KalendarID_idx` ON `Kalendar` (`KalendarID`);
CREATE INDEX IF NOT EXISTS `SMSDraft_MsgID_idx` ON `SMSDraft` (`MsgID`);
CREATE INDEX IF NOT EXISTS `Stu_Reg_NameFirst_idx` ON `Stu_Reg` (`NameFirst`);
CREATE UNIQUE INDEX IF NOT EXISTS `Stu_Reg_Stu_RegID_idx` ON `Stu_Reg` (`Stu_RegID`);
CREATE INDEX IF NOT EXISTS `StuAdv_StuCls_RegID_idx` ON `StuAdv` (`StuRegID`);
CREATE INDEX IF NOT EXISTS `Student_Class_Class_SecID_idx` ON `Student_Class` (`ClassSecID`);
CREATE INDEX IF NOT EXISTS `Student_Class_ClassID_idx` ON `Student_Class` (`ClassID`);
CREATE INDEX IF NOT EXISTS `Student_Class_Stu_RegID_idx` ON `Student_Class` (`Stu_RegID`);
CREATE INDEX IF NOT EXISTS `Subj_Class_ClassID_idx` ON `Subj_Class` (`ClassID`);
CREATE INDEX IF NOT EXISTS `Subj_Class_Subj_ClsID_idx` ON `Subj_Class` (`Subj_ClsID`);
CREATE INDEX IF NOT EXISTS `Subj_Class_SubjID_idx` ON `Subj_Class` (`SubjID`);
CREATE INDEX IF NOT EXISTS `Subj_Class_TeacherID_idx` ON `Subj_Class` (`TeacherID`);
CREATE INDEX IF NOT EXISTS `TAtt_TAttID_idx` ON `TAtt` (`TAttID`);
CREATE INDEX IF NOT EXISTS `TAtt_TeacherID_idx` ON `TAtt` (`TeacherID`);
CREATE UNIQUE INDEX IF NOT EXISTS `Teachers_TBioSer_idx` ON `Teachers` (`TBioSer`);
CREATE INDEX IF NOT EXISTS `TEmp_Lvl_TeacherID_idx` ON `TEmp_Lvl` (`TeacherID`);
CREATE INDEX IF NOT EXISTS `TEmp_Lvl_TEmpLvlID_idx` ON `TEmp_Lvl` (`TSalLvlID`);
CREATE INDEX IF NOT EXISTS `TempPromo_Stu_RedID_idx` ON `TempPromo` (`Stu_RegID`);
CREATE INDEX IF NOT EXISTS `TSalDet_TSalDetID_idx` ON `TSalDet` (`TSalDetSer`);
CREATE INDEX IF NOT EXISTS `TSalDet_TSalMasID_idx` ON `TSalDet` (`TSalMasID`);
CREATE INDEX IF NOT EXISTS `TSalInc_EmpID_idx` ON `TSalInc` (`EmpID`);
CREATE UNIQUE INDEX IF NOT EXISTS `TSalInc_TSalIncID_idx` ON `TSalInc` (`TSalIncID`);
CREATE INDEX IF NOT EXISTS `TSalInc_TSalLvlID_idx` ON `TSalInc` (`TSalLvlID`);
CREATE INDEX IF NOT EXISTS `TSalLvlAmount_SalParamID_idx` ON `TSalLvlAmount` (`SalParamID`);
CREATE INDEX IF NOT EXISTS `TSalLvlAmount_T_SalID_idx` ON `TSalLvlAmount` (`T_SalTD`);
CREATE INDEX IF NOT EXISTS `TSalLvlAmount_TSalLvlDetailSalLvl_idx` ON `TSalLvlAmount` (`SalLvl`);
CREATE INDEX IF NOT EXISTS `TSalMas_IsPaid_idx` ON `TSalMas` (`IsPaid`);
CREATE INDEX IF NOT EXISTS `TSalMas_TeacherID_idx` ON `TSalMas` (`TeacherID`);
CREATE UNIQUE INDEX IF NOT EXISTS `TSalMas_TSalMasID_idx` ON `TSalMas` (`TSalMasID`);
CREATE INDEX IF NOT EXISTS `VoucharDet_feeStructureID_idx` ON `VoucharDet` (`feeParameterID`);
CREATE INDEX IF NOT EXISTS `VoucharDet_VoucharMasID_idx` ON `VoucharDet` (`VoucharMasID`);
CREATE INDEX IF NOT EXISTS `VoucharMas_ClassID_idx` ON `VoucharMas` (`ClassID`);
CREATE INDEX IF NOT EXISTS `VoucharMas_IsPaid_idx` ON `VoucharMas` (`IsPaid`);
CREATE INDEX IF NOT EXISTS `VoucharMas_SessionYr_idx` ON `VoucharMas` (`SessionYr`);
CREATE INDEX IF NOT EXISTS `VoucharMas_StudentClassID_idx` ON `VoucharMas` (`Student_Class_StuRegID`);
CREATE UNIQUE INDEX IF NOT EXISTS `VoucharMas_VoucherMasID_idx` ON `VoucharMas` (`VoucherMasID`);
CREATE INDEX IF NOT EXISTS `ExamDet_ExamID_idx` ON `ExamDet` (`ExamInfoID`);
CREATE INDEX IF NOT EXISTS `ExamDet_ExamMasID_idx` ON `ExamDet` (`ExamMasID`);
CREATE INDEX IF NOT EXISTS `ExamDet_SubjID_idx` ON `ExamDet` (`SubjID`);
CREATE INDEX IF NOT EXISTS `SchLeaving_SLID_idx` ON `SchLeaving` (`SLID`);
CREATE INDEX IF NOT EXISTS `SchLeaving_StuRegID_idx` ON `SchLeaving` (`StuRegID`);
CREATE INDEX IF NOT EXISTS `TSalParam_T_SalID_idx` ON `TSalParam` (`SalParamID`);
