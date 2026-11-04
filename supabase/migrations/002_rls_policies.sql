-- Phase F-2 / 002: RLS policies and RPC grants for the 19 synced tables.
-- RLS is enabled on every table. Only authenticated may access.
-- SECURITY DEFINER upsert RPCs are revoked from PUBLIC/anon.

ALTER TABLE "Stu_Reg" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "Stu_Reg" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Stu_Reg" TO authenticated;

CREATE POLICY "sel_Stu_Reg_auth" ON "Stu_Reg" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_Stu_Reg_auth" ON "Stu_Reg" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_Stu_Reg_auth" ON "Stu_Reg" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_Stu_Reg_auth" ON "Stu_Reg" FOR DELETE TO authenticated USING (true);

ALTER TABLE "Student_Class" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "Student_Class" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Student_Class" TO authenticated;

CREATE POLICY "sel_Student_Class_auth" ON "Student_Class" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_Student_Class_auth" ON "Student_Class" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_Student_Class_auth" ON "Student_Class" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_Student_Class_auth" ON "Student_Class" FOR DELETE TO authenticated USING (true);

ALTER TABLE "Sibling_Links" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "Sibling_Links" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Sibling_Links" TO authenticated;

CREATE POLICY "sel_Sibling_Links_auth" ON "Sibling_Links" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_Sibling_Links_auth" ON "Sibling_Links" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_Sibling_Links_auth" ON "Sibling_Links" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_Sibling_Links_auth" ON "Sibling_Links" FOR DELETE TO authenticated USING (true);

ALTER TABLE "VoucharMas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "VoucharMas" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "VoucharMas" TO authenticated;

CREATE POLICY "sel_VoucharMas_auth" ON "VoucharMas" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_VoucharMas_auth" ON "VoucharMas" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_VoucharMas_auth" ON "VoucharMas" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_VoucharMas_auth" ON "VoucharMas" FOR DELETE TO authenticated USING (true);

ALTER TABLE "VoucharDet" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "VoucharDet" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "VoucharDet" TO authenticated;

CREATE POLICY "sel_VoucharDet_auth" ON "VoucharDet" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_VoucharDet_auth" ON "VoucharDet" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_VoucharDet_auth" ON "VoucharDet" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_VoucharDet_auth" ON "VoucharDet" FOR DELETE TO authenticated USING (true);

ALTER TABLE "FeeTransaction" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "FeeTransaction" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "FeeTransaction" TO authenticated;

CREATE POLICY "sel_FeeTransaction_auth" ON "FeeTransaction" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_FeeTransaction_auth" ON "FeeTransaction" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_FeeTransaction_auth" ON "FeeTransaction" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_FeeTransaction_auth" ON "FeeTransaction" FOR DELETE TO authenticated USING (true);

ALTER TABLE "StuAdv" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "StuAdv" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "StuAdv" TO authenticated;

CREATE POLICY "sel_StuAdv_auth" ON "StuAdv" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_StuAdv_auth" ON "StuAdv" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_StuAdv_auth" ON "StuAdv" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_StuAdv_auth" ON "StuAdv" FOR DELETE TO authenticated USING (true);

ALTER TABLE "AttMas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "AttMas" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "AttMas" TO authenticated;

CREATE POLICY "sel_AttMas_auth" ON "AttMas" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_AttMas_auth" ON "AttMas" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_AttMas_auth" ON "AttMas" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_AttMas_auth" ON "AttMas" FOR DELETE TO authenticated USING (true);

ALTER TABLE "AttDet" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "AttDet" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "AttDet" TO authenticated;

CREATE POLICY "sel_AttDet_auth" ON "AttDet" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_AttDet_auth" ON "AttDet" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_AttDet_auth" ON "AttDet" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_AttDet_auth" ON "AttDet" FOR DELETE TO authenticated USING (true);

ALTER TABLE "TAtt" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "TAtt" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "TAtt" TO authenticated;

CREATE POLICY "sel_TAtt_auth" ON "TAtt" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_TAtt_auth" ON "TAtt" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_TAtt_auth" ON "TAtt" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_TAtt_auth" ON "TAtt" FOR DELETE TO authenticated USING (true);

ALTER TABLE "Teachers" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "Teachers" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Teachers" TO authenticated;

CREATE POLICY "sel_Teachers_auth" ON "Teachers" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_Teachers_auth" ON "Teachers" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_Teachers_auth" ON "Teachers" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_Teachers_auth" ON "Teachers" FOR DELETE TO authenticated USING (true);

ALTER TABLE "TSalMas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "TSalMas" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "TSalMas" TO authenticated;

CREATE POLICY "sel_TSalMas_auth" ON "TSalMas" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_TSalMas_auth" ON "TSalMas" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_TSalMas_auth" ON "TSalMas" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_TSalMas_auth" ON "TSalMas" FOR DELETE TO authenticated USING (true);

ALTER TABLE "TSalDet" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "TSalDet" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "TSalDet" TO authenticated;

CREATE POLICY "sel_TSalDet_auth" ON "TSalDet" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_TSalDet_auth" ON "TSalDet" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_TSalDet_auth" ON "TSalDet" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_TSalDet_auth" ON "TSalDet" FOR DELETE TO authenticated USING (true);

ALTER TABLE "ExamInfo" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "ExamInfo" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "ExamInfo" TO authenticated;

CREATE POLICY "sel_ExamInfo_auth" ON "ExamInfo" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_ExamInfo_auth" ON "ExamInfo" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_ExamInfo_auth" ON "ExamInfo" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_ExamInfo_auth" ON "ExamInfo" FOR DELETE TO authenticated USING (true);

ALTER TABLE "ExamMas" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "ExamMas" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "ExamMas" TO authenticated;

CREATE POLICY "sel_ExamMas_auth" ON "ExamMas" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_ExamMas_auth" ON "ExamMas" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_ExamMas_auth" ON "ExamMas" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_ExamMas_auth" ON "ExamMas" FOR DELETE TO authenticated USING (true);

ALTER TABLE "ExamDet" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "ExamDet" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "ExamDet" TO authenticated;

CREATE POLICY "sel_ExamDet_auth" ON "ExamDet" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_ExamDet_auth" ON "ExamDet" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_ExamDet_auth" ON "ExamDet" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_ExamDet_auth" ON "ExamDet" FOR DELETE TO authenticated USING (true);

ALTER TABLE "SchLeaving" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "SchLeaving" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "SchLeaving" TO authenticated;

CREATE POLICY "sel_SchLeaving_auth" ON "SchLeaving" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_SchLeaving_auth" ON "SchLeaving" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_SchLeaving_auth" ON "SchLeaving" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_SchLeaving_auth" ON "SchLeaving" FOR DELETE TO authenticated USING (true);

ALTER TABLE "Books" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "Books" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Books" TO authenticated;

CREATE POLICY "sel_Books_auth" ON "Books" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_Books_auth" ON "Books" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_Books_auth" ON "Books" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_Books_auth" ON "Books" FOR DELETE TO authenticated USING (true);

ALTER TABLE "app_config" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON "app_config" FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON "app_config" TO authenticated;

CREATE POLICY "sel_app_config_auth" ON "app_config" FOR SELECT TO authenticated USING (true);
CREATE POLICY "ins_app_config_auth" ON "app_config" FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "upd_app_config_auth" ON "app_config" FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "del_app_config_auth" ON "app_config" FOR DELETE TO authenticated USING (true);

REVOKE ALL ON FUNCTION public."upsert_Stu_Reg"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_Stu_Reg"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_Stu_Reg"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_Student_Class"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_Student_Class"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_Student_Class"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_Sibling_Links"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_Sibling_Links"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_Sibling_Links"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_VoucharMas"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_VoucharMas"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_VoucharMas"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_VoucharDet"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_VoucharDet"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_VoucharDet"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_FeeTransaction"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_FeeTransaction"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_FeeTransaction"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_StuAdv"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_StuAdv"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_StuAdv"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_AttMas"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_AttMas"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_AttMas"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_AttDet"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_AttDet"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_AttDet"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_TAtt"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_TAtt"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_TAtt"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_Teachers"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_Teachers"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_Teachers"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_TSalMas"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_TSalMas"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_TSalMas"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_TSalDet"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_TSalDet"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_TSalDet"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_ExamInfo"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_ExamInfo"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_ExamInfo"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_ExamMas"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_ExamMas"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_ExamMas"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_ExamDet"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_ExamDet"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_ExamDet"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_SchLeaving"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_SchLeaving"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_SchLeaving"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_Books"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_Books"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_Books"(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public."upsert_app_config"(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public."upsert_app_config"(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public."upsert_app_config"(jsonb) TO authenticated;

-- Service role grants for bulk seeder
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
NOTIFY pgrst, 'reload schema';
