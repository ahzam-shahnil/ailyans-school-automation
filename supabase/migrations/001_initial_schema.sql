-- Phase F-2 / 001: Supabase PostgreSQL schema for the 19 synced tables.
-- Generated from the live SQLite .schema dump; every identifier is double-quoted.
-- No foreign keys in F-2. Every table has updated_at + a BEFORE UPDATE trigger.
-- Each table also has a case-preserving SECURITY DEFINER upsert RPC.

CREATE TABLE IF NOT EXISTS "Stu_Reg" (
    "Stu_RegID" BIGINT NOT NULL,
    "NameFirst" TEXT NOT NULL,
    "NameMiddle" TEXT,
    "NameLast" TEXT,
    "DOB" TEXT,
    "B_Form_No" TEXT,
    "F_Name" TEXT,
    "CNIC_No" TEXT,
    "Occupation" TEXT,
    "P_Address" TEXT,
    "T_Address" TEXT,
    "Phone_Office" TEXT,
    "Phone_Res" TEXT,
    "Mobile1" TEXT,
    "Mobile2" TEXT,
    "Religion" TEXT,
    "P_School" TEXT,
    "SLCertificate" TEXT,
    "P_Class" TEXT,
    "AdmInClass" BIGINT,
    "AdmClass" BIGINT,
    "DOAdmission" TEXT,
    "DocsDetail" TEXT,
    "Discount" DOUBLE PRECISION,
    "EmerContName" TEXT,
    "EmerContMobile" TEXT,
    "OfficeFile" TEXT,
    "Remarls" TEXT,
    "VMDiscount" BIGINT,
    "FullDiscount" BIGINT NOT NULL,
    "Nationality" TEXT,
    "Sex" TEXT,
    "photo_path" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "Stu_Reg_pkey" PRIMARY KEY ("Stu_RegID")
);

CREATE TABLE IF NOT EXISTS "Student_Class" (
    "Stu_RegID" BIGINT,
    "ClassID" BIGINT,
    "ClassSecID" BIGINT,
    "ClassRollNo" BIGINT,
    "SessionYr" TEXT NOT NULL,
    "Present" BIGINT NOT NULL,
    "PassingMarks" BIGINT,
    "PromotionDate" TEXT,
    "VGen" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "Student_Class_pkey" PRIMARY KEY ("Stu_RegID", "ClassID", "SessionYr")
);

CREATE TABLE IF NOT EXISTS "Sibling_Links" (
    "LinkID" BIGINT,
    "Stu1_RegID" BIGINT NOT NULL,
    "Stu2_RegID" BIGINT NOT NULL,
    "Relation" TEXT,
    "LinkedBy" TEXT,
    "LinkedOn" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "Sibling_Links_pkey" PRIMARY KEY ("LinkID"),
    CONSTRAINT "Sibling_Links_Stu1_Stu2_key" UNIQUE ("Stu1_RegID", "Stu2_RegID"),
    CONSTRAINT "Sibling_Links_pair_check" CHECK ("Stu1_RegID" < "Stu2_RegID")
);

CREATE TABLE IF NOT EXISTS "VoucharMas" (
    "VoucherMasID" TEXT,
    "VDate" TEXT,
    "Student_Class_StuRegID" BIGINT,
    "SubTotal" BIGINT,
    "ForMonth" TEXT,
    "ClassID" BIGINT,
    "Remarks" TEXT,
    "Discount" BIGINT,
    "DueDate" TEXT,
    "IsPaid" TEXT,
    "SessionYr" TEXT,
    "PaidAmt" BIGINT DEFAULT 0,
    "PaidDate" TEXT,
    "BankID" BIGINT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "VoucharMas_pkey" PRIMARY KEY ("VoucherMasID")
);

CREATE TABLE IF NOT EXISTS "VoucharDet" (
    "VoucharDetID" DOUBLE PRECISION,
    "VoucharMasID" TEXT,
    "feeParameterID" BIGINT,
    "Amount" DOUBLE PRECISION,
    "Discount" DOUBLE PRECISION,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "VoucharDet_pkey" PRIMARY KEY ("VoucharDetID", "VoucharMasID", "feeParameterID")
);

CREATE TABLE IF NOT EXISTS "FeeTransaction" (
    "FeeTransID" BIGINT,
    "BankID" BIGINT,
    "SubmissionDate" TEXT,
    "VoucharNo" TEXT,
    "TotalAmount" BIGINT,
    "PaidAmount" BIGINT,
    "Detail" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "FeeTransaction_pkey" PRIMARY KEY ("FeeTransID")
);

CREATE TABLE IF NOT EXISTS "StuAdv" (
    "StuAdvID" BIGINT,
    "StuRegID" BIGINT,
    "AdvAmount" BIGINT,
    "MOP" TEXT,
    "Date" TEXT,
    "DepositedBy" TEXT,
    "Detail" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "StuAdv_pkey" PRIMARY KEY ("StuAdvID")
);

CREATE TABLE IF NOT EXISTS "AttMas" (
    "AttMasID" BIGINT,
    "TeacherID" BIGINT,
    "ClassID" BIGINT NOT NULL,
    "ClassSecID" BIGINT NOT NULL,
    "AttDate" TEXT,
    "StudySessionYr" TEXT,
    "Remarks" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "AttMas_pkey" PRIMARY KEY ("ClassID", "ClassSecID", "AttDate")
);

CREATE TABLE IF NOT EXISTS "AttDet" (
    "AttDetID" BIGINT,
    "AttMasID" BIGINT NOT NULL,
    "Stu_RegID" BIGINT NOT NULL,
    "AttStatus" TEXT NOT NULL,
    "InTime" TEXT,
    "OutTime" TEXT,
    "AttAppcation" TEXT,
    "LeaveRequestedBy" TEXT,
    "LFrom" TEXT,
    "LTill" TEXT,
    "Reason" TEXT,
    "IsApproved" TEXT,
    "AttRemarks" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "AttDet_pkey" PRIMARY KEY ("AttMasID", "Stu_RegID")
);

CREATE TABLE IF NOT EXISTS "TAtt" (
    "TAttID" BIGINT,
    "TeacherID" BIGINT NOT NULL,
    "AttDate" TEXT,
    "Status" TEXT,
    "InTime" TEXT,
    "OutTime" TEXT,
    "LeaveReason" TEXT,
    "Remarks" TEXT,
    "SessionYr" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "TAtt_pkey" PRIMARY KEY ("TeacherID", "AttDate")
);

CREATE TABLE IF NOT EXISTS "Teachers" (
    "TeacherID" BIGINT,
    "TName" TEXT NOT NULL,
    "TFName" TEXT,
    "TCNIC" TEXT NOT NULL,
    "DOB" TEXT,
    "TContactNo1" TEXT NOT NULL,
    "TContactNo2" TEXT,
    "TAddress" TEXT,
    "Domicile" TEXT,
    "TSubject" TEXT,
    "DOJoing" TEXT,
    "Detail" TEXT,
    "TIsPresent" TEXT NOT NULL,
    "TEmergencyContactName" TEXT,
    "TEmergencyContactNo" TEXT,
    "TDoLeft" TEXT,
    "TQualification" TEXT,
    "TProfessional" TEXT,
    "TCertificate" TEXT,
    "TFiledOfExperty" TEXT,
    "TExperience" TEXT,
    "TAnySpeciality" TEXT,
    "OfficeFile" TEXT,
    "TCat" TEXT,
    "TBioSer" DOUBLE PRECISION,
    "AttSMSCont" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "Teachers_pkey" PRIMARY KEY ("TeacherID")
);

CREATE TABLE IF NOT EXISTS "TSalMas" (
    "TSalMasID" TEXT,
    "TeacherID" BIGINT,
    "DisbursDate" TEXT,
    "SalMonth" TEXT,
    "PaidAmt" BIGINT,
    "TDeductions" BIGINT,
    "Detail" TEXT,
    "IsPaid" TEXT,
    "PaidDate" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "TSalMas_pkey" PRIMARY KEY ("TeacherID", "SalMonth")
);

CREATE TABLE IF NOT EXISTS "TSalDet" (
    "TSalDetSer" BIGINT,
    "TSalMasID" TEXT,
    "Detail" TEXT,
    "Amount" BIGINT,
    "Remarks" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "TSalDet_pkey" PRIMARY KEY ("TSalMasID", "Detail")
);

CREATE TABLE IF NOT EXISTS "ExamInfo" (
    "ExamInfoID" BIGINT,
    "ExTermID" BIGINT NOT NULL,
    "SessionYR" TEXT,
    "StartDate" TEXT,
    "EndDate" TEXT,
    "ResultDate" TEXT,
    "ExamSupervisorID" BIGINT,
    "Location" TEXT,
    "Detail" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "ExamInfo_pkey" PRIMARY KEY ("ExTermID", "SessionYR")
);

CREATE TABLE IF NOT EXISTS "ExamMas" (
    "ExamMasID" BIGINT,
    "ExamInfoID" BIGINT,
    "ExTermID" BIGINT,
    "ClassID" BIGINT,
    "ClassSecID" BIGINT,
    "Stu_RegID" BIGINT,
    "TeacherID" BIGINT,
    "Detail" TEXT,
    "SessionYr" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "ExamMas_pkey" PRIMARY KEY ("ExamInfoID", "Stu_RegID")
);

CREATE TABLE IF NOT EXISTS "ExamDet" (
    "ExDetID" BIGINT,
    "ExamInfoID" BIGINT,
    "ExamMasID" BIGINT,
    "SubjID" BIGINT,
    "ObtainedMarks" BIGINT,
    "TotalMarks" BIGINT,
    "ObtainedPracMarks" BIGINT,
    "TotalPracticalMarks" BIGINT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "ExamDet_pkey" PRIMARY KEY ("ExamMasID", "SubjID")
);

CREATE TABLE IF NOT EXISTS "SchLeaving" (
    "SLID" BIGINT,
    "StuRegID" BIGINT NOT NULL,
    "LeftDate" TEXT,
    "LeftClass" BIGINT,
    "Charactor" TEXT,
    "TermOfLeavign" TEXT,
    "SLCertificate" BIGINT NOT NULL,
    "Remarks" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "SchLeaving_pkey" PRIMARY KEY ("StuRegID")
);

CREATE TABLE IF NOT EXISTS "Books" (
    "BookID" BIGINT,
    "BookCatSubj" BIGINT,
    "BookName" TEXT,
    "BAuthor" TEXT,
    "Pages" BIGINT,
    "PulishedBy" TEXT,
    "PublishedYr" BIGINT,
    "BookPrice" BIGINT,
    "Detail" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "Books_pkey" PRIMARY KEY ("BookID")
);

CREATE TABLE IF NOT EXISTS "app_config" (
    "config_key" TEXT,
    "config_value" TEXT,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT "app_config_pkey" PRIMARY KEY ("config_key")
);

CREATE OR REPLACE FUNCTION public."set_updated_at"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW."updated_at" := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER "Stu_Reg_updated_at"
BEFORE UPDATE ON "Stu_Reg"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "Student_Class_updated_at"
BEFORE UPDATE ON "Student_Class"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "Sibling_Links_updated_at"
BEFORE UPDATE ON "Sibling_Links"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "VoucharMas_updated_at"
BEFORE UPDATE ON "VoucharMas"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "VoucharDet_updated_at"
BEFORE UPDATE ON "VoucharDet"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "FeeTransaction_updated_at"
BEFORE UPDATE ON "FeeTransaction"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "StuAdv_updated_at"
BEFORE UPDATE ON "StuAdv"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "AttMas_updated_at"
BEFORE UPDATE ON "AttMas"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "AttDet_updated_at"
BEFORE UPDATE ON "AttDet"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "TAtt_updated_at"
BEFORE UPDATE ON "TAtt"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "Teachers_updated_at"
BEFORE UPDATE ON "Teachers"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "TSalMas_updated_at"
BEFORE UPDATE ON "TSalMas"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "TSalDet_updated_at"
BEFORE UPDATE ON "TSalDet"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "ExamInfo_updated_at"
BEFORE UPDATE ON "ExamInfo"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "ExamMas_updated_at"
BEFORE UPDATE ON "ExamMas"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "ExamDet_updated_at"
BEFORE UPDATE ON "ExamDet"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "SchLeaving_updated_at"
BEFORE UPDATE ON "SchLeaving"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "Books_updated_at"
BEFORE UPDATE ON "Books"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE TRIGGER "app_config_updated_at"
BEFORE UPDATE ON "app_config"
FOR EACH ROW EXECUTE FUNCTION public."set_updated_at"();

CREATE OR REPLACE FUNCTION public."upsert_Stu_Reg"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "Stu_Reg"
        SELECT * FROM jsonb_populate_record(NULL::"Stu_Reg", p_payload)
    ON CONFLICT ("Stu_RegID") DO UPDATE SET
        "NameFirst" = EXCLUDED."NameFirst",
        "NameMiddle" = EXCLUDED."NameMiddle",
        "NameLast" = EXCLUDED."NameLast",
        "DOB" = EXCLUDED."DOB",
        "B_Form_No" = EXCLUDED."B_Form_No",
        "F_Name" = EXCLUDED."F_Name",
        "CNIC_No" = EXCLUDED."CNIC_No",
        "Occupation" = EXCLUDED."Occupation",
        "P_Address" = EXCLUDED."P_Address",
        "T_Address" = EXCLUDED."T_Address",
        "Phone_Office" = EXCLUDED."Phone_Office",
        "Phone_Res" = EXCLUDED."Phone_Res",
        "Mobile1" = EXCLUDED."Mobile1",
        "Mobile2" = EXCLUDED."Mobile2",
        "Religion" = EXCLUDED."Religion",
        "P_School" = EXCLUDED."P_School",
        "SLCertificate" = EXCLUDED."SLCertificate",
        "P_Class" = EXCLUDED."P_Class",
        "AdmInClass" = EXCLUDED."AdmInClass",
        "AdmClass" = EXCLUDED."AdmClass",
        "DOAdmission" = EXCLUDED."DOAdmission",
        "DocsDetail" = EXCLUDED."DocsDetail",
        "Discount" = EXCLUDED."Discount",
        "EmerContName" = EXCLUDED."EmerContName",
        "EmerContMobile" = EXCLUDED."EmerContMobile",
        "OfficeFile" = EXCLUDED."OfficeFile",
        "Remarls" = EXCLUDED."Remarls",
        "VMDiscount" = EXCLUDED."VMDiscount",
        "FullDiscount" = EXCLUDED."FullDiscount",
        "Nationality" = EXCLUDED."Nationality",
        "Sex" = EXCLUDED."Sex",
        "photo_path" = EXCLUDED."photo_path",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_Student_Class"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "Student_Class"
        SELECT * FROM jsonb_populate_record(NULL::"Student_Class", p_payload)
    ON CONFLICT ("Stu_RegID", "ClassID", "SessionYr") DO UPDATE SET
        "ClassSecID" = EXCLUDED."ClassSecID",
        "ClassRollNo" = EXCLUDED."ClassRollNo",
        "Present" = EXCLUDED."Present",
        "PassingMarks" = EXCLUDED."PassingMarks",
        "PromotionDate" = EXCLUDED."PromotionDate",
        "VGen" = EXCLUDED."VGen",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_Sibling_Links"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "Sibling_Links"
        SELECT * FROM jsonb_populate_record(NULL::"Sibling_Links", p_payload)
    ON CONFLICT ("LinkID") DO UPDATE SET
        "Stu1_RegID" = EXCLUDED."Stu1_RegID",
        "Stu2_RegID" = EXCLUDED."Stu2_RegID",
        "Relation" = EXCLUDED."Relation",
        "LinkedBy" = EXCLUDED."LinkedBy",
        "LinkedOn" = EXCLUDED."LinkedOn",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_VoucharMas"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "VoucharMas"
        SELECT * FROM jsonb_populate_record(NULL::"VoucharMas", p_payload)
    ON CONFLICT ("VoucherMasID") DO UPDATE SET
        "VDate" = EXCLUDED."VDate",
        "Student_Class_StuRegID" = EXCLUDED."Student_Class_StuRegID",
        "SubTotal" = EXCLUDED."SubTotal",
        "ForMonth" = EXCLUDED."ForMonth",
        "ClassID" = EXCLUDED."ClassID",
        "Remarks" = EXCLUDED."Remarks",
        "Discount" = EXCLUDED."Discount",
        "DueDate" = EXCLUDED."DueDate",
        "IsPaid" = EXCLUDED."IsPaid",
        "SessionYr" = EXCLUDED."SessionYr",
        "PaidAmt" = EXCLUDED."PaidAmt",
        "PaidDate" = EXCLUDED."PaidDate",
        "BankID" = EXCLUDED."BankID",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_VoucharDet"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "VoucharDet"
        SELECT * FROM jsonb_populate_record(NULL::"VoucharDet", p_payload)
    ON CONFLICT ("VoucharDetID", "VoucharMasID", "feeParameterID") DO UPDATE SET
        "Amount" = EXCLUDED."Amount",
        "Discount" = EXCLUDED."Discount",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_FeeTransaction"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "FeeTransaction"
        SELECT * FROM jsonb_populate_record(NULL::"FeeTransaction", p_payload)
    ON CONFLICT ("FeeTransID") DO UPDATE SET
        "BankID" = EXCLUDED."BankID",
        "SubmissionDate" = EXCLUDED."SubmissionDate",
        "VoucharNo" = EXCLUDED."VoucharNo",
        "TotalAmount" = EXCLUDED."TotalAmount",
        "PaidAmount" = EXCLUDED."PaidAmount",
        "Detail" = EXCLUDED."Detail",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_StuAdv"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "StuAdv"
        SELECT * FROM jsonb_populate_record(NULL::"StuAdv", p_payload)
    ON CONFLICT ("StuAdvID") DO UPDATE SET
        "StuRegID" = EXCLUDED."StuRegID",
        "AdvAmount" = EXCLUDED."AdvAmount",
        "MOP" = EXCLUDED."MOP",
        "Date" = EXCLUDED."Date",
        "DepositedBy" = EXCLUDED."DepositedBy",
        "Detail" = EXCLUDED."Detail",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_AttMas"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "AttMas"
        SELECT * FROM jsonb_populate_record(NULL::"AttMas", p_payload)
    ON CONFLICT ("ClassID", "ClassSecID", "AttDate") DO UPDATE SET
        "AttMasID" = EXCLUDED."AttMasID",
        "TeacherID" = EXCLUDED."TeacherID",
        "StudySessionYr" = EXCLUDED."StudySessionYr",
        "Remarks" = EXCLUDED."Remarks",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_AttDet"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "AttDet"
        SELECT * FROM jsonb_populate_record(NULL::"AttDet", p_payload)
    ON CONFLICT ("AttMasID", "Stu_RegID") DO UPDATE SET
        "AttDetID" = EXCLUDED."AttDetID",
        "AttStatus" = EXCLUDED."AttStatus",
        "InTime" = EXCLUDED."InTime",
        "OutTime" = EXCLUDED."OutTime",
        "AttAppcation" = EXCLUDED."AttAppcation",
        "LeaveRequestedBy" = EXCLUDED."LeaveRequestedBy",
        "LFrom" = EXCLUDED."LFrom",
        "LTill" = EXCLUDED."LTill",
        "Reason" = EXCLUDED."Reason",
        "IsApproved" = EXCLUDED."IsApproved",
        "AttRemarks" = EXCLUDED."AttRemarks",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_TAtt"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "TAtt"
        SELECT * FROM jsonb_populate_record(NULL::"TAtt", p_payload)
    ON CONFLICT ("TeacherID", "AttDate") DO UPDATE SET
        "TAttID" = EXCLUDED."TAttID",
        "Status" = EXCLUDED."Status",
        "InTime" = EXCLUDED."InTime",
        "OutTime" = EXCLUDED."OutTime",
        "LeaveReason" = EXCLUDED."LeaveReason",
        "Remarks" = EXCLUDED."Remarks",
        "SessionYr" = EXCLUDED."SessionYr",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_Teachers"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "Teachers"
        SELECT * FROM jsonb_populate_record(NULL::"Teachers", p_payload)
    ON CONFLICT ("TeacherID") DO UPDATE SET
        "TName" = EXCLUDED."TName",
        "TFName" = EXCLUDED."TFName",
        "TCNIC" = EXCLUDED."TCNIC",
        "DOB" = EXCLUDED."DOB",
        "TContactNo1" = EXCLUDED."TContactNo1",
        "TContactNo2" = EXCLUDED."TContactNo2",
        "TAddress" = EXCLUDED."TAddress",
        "Domicile" = EXCLUDED."Domicile",
        "TSubject" = EXCLUDED."TSubject",
        "DOJoing" = EXCLUDED."DOJoing",
        "Detail" = EXCLUDED."Detail",
        "TIsPresent" = EXCLUDED."TIsPresent",
        "TEmergencyContactName" = EXCLUDED."TEmergencyContactName",
        "TEmergencyContactNo" = EXCLUDED."TEmergencyContactNo",
        "TDoLeft" = EXCLUDED."TDoLeft",
        "TQualification" = EXCLUDED."TQualification",
        "TProfessional" = EXCLUDED."TProfessional",
        "TCertificate" = EXCLUDED."TCertificate",
        "TFiledOfExperty" = EXCLUDED."TFiledOfExperty",
        "TExperience" = EXCLUDED."TExperience",
        "TAnySpeciality" = EXCLUDED."TAnySpeciality",
        "OfficeFile" = EXCLUDED."OfficeFile",
        "TCat" = EXCLUDED."TCat",
        "TBioSer" = EXCLUDED."TBioSer",
        "AttSMSCont" = EXCLUDED."AttSMSCont",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_TSalMas"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "TSalMas"
        SELECT * FROM jsonb_populate_record(NULL::"TSalMas", p_payload)
    ON CONFLICT ("TeacherID", "SalMonth") DO UPDATE SET
        "TSalMasID" = EXCLUDED."TSalMasID",
        "DisbursDate" = EXCLUDED."DisbursDate",
        "PaidAmt" = EXCLUDED."PaidAmt",
        "TDeductions" = EXCLUDED."TDeductions",
        "Detail" = EXCLUDED."Detail",
        "IsPaid" = EXCLUDED."IsPaid",
        "PaidDate" = EXCLUDED."PaidDate",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_TSalDet"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "TSalDet"
        SELECT * FROM jsonb_populate_record(NULL::"TSalDet", p_payload)
    ON CONFLICT ("TSalMasID", "Detail") DO UPDATE SET
        "TSalDetSer" = EXCLUDED."TSalDetSer",
        "Amount" = EXCLUDED."Amount",
        "Remarks" = EXCLUDED."Remarks",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_ExamInfo"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "ExamInfo"
        SELECT * FROM jsonb_populate_record(NULL::"ExamInfo", p_payload)
    ON CONFLICT ("ExTermID", "SessionYR") DO UPDATE SET
        "ExamInfoID" = EXCLUDED."ExamInfoID",
        "StartDate" = EXCLUDED."StartDate",
        "EndDate" = EXCLUDED."EndDate",
        "ResultDate" = EXCLUDED."ResultDate",
        "ExamSupervisorID" = EXCLUDED."ExamSupervisorID",
        "Location" = EXCLUDED."Location",
        "Detail" = EXCLUDED."Detail",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_ExamMas"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "ExamMas"
        SELECT * FROM jsonb_populate_record(NULL::"ExamMas", p_payload)
    ON CONFLICT ("ExamInfoID", "Stu_RegID") DO UPDATE SET
        "ExamMasID" = EXCLUDED."ExamMasID",
        "ExTermID" = EXCLUDED."ExTermID",
        "ClassID" = EXCLUDED."ClassID",
        "ClassSecID" = EXCLUDED."ClassSecID",
        "TeacherID" = EXCLUDED."TeacherID",
        "Detail" = EXCLUDED."Detail",
        "SessionYr" = EXCLUDED."SessionYr",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_ExamDet"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "ExamDet"
        SELECT * FROM jsonb_populate_record(NULL::"ExamDet", p_payload)
    ON CONFLICT ("ExamMasID", "SubjID") DO UPDATE SET
        "ExDetID" = EXCLUDED."ExDetID",
        "ExamInfoID" = EXCLUDED."ExamInfoID",
        "ObtainedMarks" = EXCLUDED."ObtainedMarks",
        "TotalMarks" = EXCLUDED."TotalMarks",
        "ObtainedPracMarks" = EXCLUDED."ObtainedPracMarks",
        "TotalPracticalMarks" = EXCLUDED."TotalPracticalMarks",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_SchLeaving"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "SchLeaving"
        SELECT * FROM jsonb_populate_record(NULL::"SchLeaving", p_payload)
    ON CONFLICT ("StuRegID") DO UPDATE SET
        "SLID" = EXCLUDED."SLID",
        "LeftDate" = EXCLUDED."LeftDate",
        "LeftClass" = EXCLUDED."LeftClass",
        "Charactor" = EXCLUDED."Charactor",
        "TermOfLeavign" = EXCLUDED."TermOfLeavign",
        "SLCertificate" = EXCLUDED."SLCertificate",
        "Remarks" = EXCLUDED."Remarks",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_Books"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "Books"
        SELECT * FROM jsonb_populate_record(NULL::"Books", p_payload)
    ON CONFLICT ("BookID") DO UPDATE SET
        "BookCatSubj" = EXCLUDED."BookCatSubj",
        "BookName" = EXCLUDED."BookName",
        "BAuthor" = EXCLUDED."BAuthor",
        "Pages" = EXCLUDED."Pages",
        "PulishedBy" = EXCLUDED."PulishedBy",
        "PublishedYr" = EXCLUDED."PublishedYr",
        "BookPrice" = EXCLUDED."BookPrice",
        "Detail" = EXCLUDED."Detail",
        "updated_at" = now();
END;
$$;

CREATE OR REPLACE FUNCTION public."upsert_app_config"(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    p_payload := p_payload || jsonb_build_object('updated_at', now());
    INSERT INTO "app_config"
        SELECT * FROM jsonb_populate_record(NULL::"app_config", p_payload)
    ON CONFLICT ("config_key") DO UPDATE SET
        "config_value" = EXCLUDED."config_value",
        "updated_at" = now();
END;
$$;
