-- =====================================================================
-- 示範資料：全部為虛構結構，不含任何受著作權保護的條文原文。
-- 用途：驗證資料模型可以表達 MVP-0 的核心情境——
--   「委員會會議紀錄」這一類 D/C 證據，同時滿足兩個框架的條款。
-- =====================================================================
BEGIN;
SET search_path = km, public;

-- 固定 UUID，方便測試引用
INSERT INTO tenant (id, code, name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'demo', '示範醫院');

INSERT INTO org_unit (id, tenant_id, code, name, kind) VALUES
  ('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-000000000001', 'QM',  '品質管理中心', 'department'),
  ('00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0000-000000000001', 'ICC', '感染管制委員會', 'committee');

INSERT INTO role (id, tenant_id, code, name) VALUES
  ('00000000-0000-0000-0002-000000000001', NULL, 'committee_secretary', '委員會幹事');

INSERT INTO person (id, tenant_id, display_name, email, org_unit_id) VALUES
  ('00000000-0000-0000-0003-000000000001', '00000000-0000-0000-0000-000000000001',
   '王小明', 'qm@example.org', '00000000-0000-0000-0001-000000000001');

-- 框架 A：虛構「醫院評鑑（示範）」——允許存自撰摘要，不存原文
INSERT INTO framework (id, code, name, publisher, kind, text_policy) VALUES
  ('00000000-0000-0000-0010-000000000001', 'DEMO-ACC', '醫院評鑑（示範）', '示範用', 'accreditation', 'summary'),
-- 框架 B：虛構「品質管理標準（示範）」——比照 ISO，只存結構
  ('00000000-0000-0000-0010-000000000002', 'DEMO-QMS', '品質管理標準（示範）', '示範用', 'iso', 'structure_only');

INSERT INTO framework_version (id, framework_id, version_label, effective_from, status) VALUES
  ('00000000-0000-0000-0011-000000000001', '00000000-0000-0000-0010-000000000001', '2026', '2026-01-01', 'active'),
  ('00000000-0000-0000-0011-000000000002', '00000000-0000-0000-0010-000000000002', '2025', '2025-01-01', 'active');

INSERT INTO requirement (id, framework_version_id, parent_id, code, kind, seq, title, summary) VALUES
  ('00000000-0000-0000-0012-000000000001', '00000000-0000-0000-0011-000000000001', NULL,
   '3', 'chapter', 3, '感染管制', NULL),
  ('00000000-0000-0000-0012-000000000002', '00000000-0000-0000-0011-000000000001', '00000000-0000-0000-0012-000000000001',
   '3.1', 'standard', 1, '感染管制組織運作', '（自撰摘要）委員會應定期開會、追蹤決議並檢討監測資料'),
  ('00000000-0000-0000-0012-000000000003', '00000000-0000-0000-0011-000000000002', NULL,
   '9.3', 'section', 1, '管理階層審查', NULL);

INSERT INTO crosswalk (source_requirement_id, target_requirement_id, relation, confidence, origin, review_status, rationale) VALUES
  ('00000000-0000-0000-0012-000000000002', '00000000-0000-0000-0012-000000000003',
   'partial', 0.700, 'manual', 'accepted', '兩者皆要求定期審查會議並追蹤前次決議');

-- 證據規格：感染管制委員會會議紀錄（每季、寬限 14 天）
INSERT INTO evidence_spec (id, tenant_id, code, name, record_type, pdca_phase,
                           freq_unit, freq_interval, grace_days, producer_role_id,
                           owner_org_unit_id, retention_months, status) VALUES
  ('00000000-0000-0000-0020-000000000001', '00000000-0000-0000-0000-000000000001',
   'ICC-MINUTES', '感染管制委員會會議紀錄', 'meeting_minutes', 'C',
   'quarter', 1, 14, '00000000-0000-0000-0002-000000000001',
   '00000000-0000-0000-0001-000000000002', 84, 'active');

INSERT INTO evidence_spec_element (evidence_spec_id, seq, code, name, check_method, rule) VALUES
  ('00000000-0000-0000-0020-000000000001', 1, 'meeting_date',   '會議日期',                 'presence',        '{}'),
  ('00000000-0000-0000-0020-000000000001', 2, 'chair',          '主席（應為院長或指定副院長）', 'cross_reference', '{"policy_field":"chair"}'),
  ('00000000-0000-0000-0020-000000000001', 3, 'quorum',         '出席達法定人數',             'value',           '{"min_attendance_ratio":0.5}'),
  ('00000000-0000-0000-0020-000000000001', 4, 'prev_followup',  '前次決議追蹤',               'ai_judgement',    '{}'),
  ('00000000-0000-0000-0020-000000000001', 5, 'surveillance',   '感染監測資料報告與檢討',       'ai_judgement',    '{}'),
  ('00000000-0000-0000-0020-000000000001', 6, 'resolutions',    '決議事項含負責人與期限',       'ai_judgement',    '{}');

INSERT INTO requirement_evidence_spec (requirement_id, evidence_spec_id) VALUES
  ('00000000-0000-0000-0012-000000000002', '00000000-0000-0000-0020-000000000001'),
  ('00000000-0000-0000-0012-000000000003', '00000000-0000-0000-0020-000000000001');

-- 基本款儲存：內建上傳
INSERT INTO storage_connector (id, tenant_id, kind, name) VALUES
  ('00000000-0000-0000-0030-000000000001', '00000000-0000-0000-0000-000000000001', 'builtin', '內建上傳');

-- 規章（P）與一份會議紀錄（D/C）
INSERT INTO artifact (id, tenant_id, kind, title, doc_number, org_unit_id) VALUES
  ('00000000-0000-0000-0031-000000000001', '00000000-0000-0000-0000-000000000001',
   'policy', '感染管制委員會設置辦法', 'ICC-P-001', '00000000-0000-0000-0001-000000000002'),
  ('00000000-0000-0000-0031-000000000002', '00000000-0000-0000-0000-000000000001',
   'record', '115 年第 3 季感染管制委員會會議紀錄', NULL, '00000000-0000-0000-0001-000000000002');

INSERT INTO artifact_version (id, artifact_id, version_no, connector_id, external_id, source,
                              effective_from, period_start, period_end, extract_status) VALUES
  ('00000000-0000-0000-0032-000000000001', '00000000-0000-0000-0031-000000000001', 1,
   '00000000-0000-0000-0030-000000000001', 'builtin/icc-p-001-v1.pdf', 'upload', '2025-07-01', NULL, NULL, 'done'),
  ('00000000-0000-0000-0032-000000000002', '00000000-0000-0000-0031-000000000002', 1,
   '00000000-0000-0000-0030-000000000001', 'builtin/icc-2026q3.pdf', 'upload', NULL, '2026-09-15', '2026-09-15', 'done');

INSERT INTO artifact_requirement (artifact_id, requirement_id, origin, review_status) VALUES
  ('00000000-0000-0000-0031-000000000001', '00000000-0000-0000-0012-000000000002', 'manual', 'accepted');

INSERT INTO evidence_item (id, tenant_id, artifact_version_id, evidence_spec_id, org_unit_id,
                           period_start, period_end, classified_by, confidence, status) VALUES
  ('00000000-0000-0000-0040-000000000001', '00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0032-000000000002', '00000000-0000-0000-0020-000000000001',
   '00000000-0000-0000-0001-000000000002', '2026-07-01', '2026-09-30', 'human', 1.000, 'confirmed');

COMMIT;
