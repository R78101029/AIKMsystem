-- =====================================================================
-- 0001_knowledge_core.sql
-- 知識核心（Knowledge Core）初版資料模型
--
-- 設計原則（詳見 docs/02-data-model.md）：
--   1. 條款級：標準框架 → 版本 → 條款樹；條款是所有關聯的錨點。
--   2. 證據規格：把每條要求拆成「什麼紀錄、多久一次、誰產生、需含哪些要素」。
--   3. 檔案不搬家：系統只存 metadata 與指向外部儲存的參照（轉接器）。
--      Metadata 以本資料庫為準（source of truth）。
--   4. 著作權：framework.text_policy = 'structure_only' 時，條款不得存原文。
--   5. AI 可稽核：每次 AI 判斷都記 ai_run；人審結果可回流成黃金測試集。
--   6. 多院：所有租戶資料都帶 tenant_id；tenant_id 為 NULL 表示全域共用目錄。
-- =====================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;
CREATE SCHEMA IF NOT EXISTS km;
SET search_path = km, public;

-- ---------------------------------------------------------------------
-- 0. 租戶與組織
-- ---------------------------------------------------------------------
CREATE TABLE tenant (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code        text NOT NULL UNIQUE,
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE org_unit (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid NOT NULL REFERENCES tenant(id),
    parent_id   uuid REFERENCES org_unit(id),
    code        text NOT NULL,
    name        text NOT NULL,
    kind        text NOT NULL DEFAULT 'department'
                CHECK (kind IN ('hospital','division','department','committee','team','other')),
    active      boolean NOT NULL DEFAULT true,
    UNIQUE (tenant_id, code)
);

-- 職務角色（如：感管護理師、品管專員），用於「誰產生紀錄」
CREATE TABLE role (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid REFERENCES tenant(id),          -- NULL = 全域範本角色
    code        text NOT NULL,
    name        text NOT NULL,
    UNIQUE NULLS NOT DISTINCT (tenant_id, code)
);

CREATE TABLE person (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     uuid NOT NULL REFERENCES tenant(id),
    display_name  text NOT NULL,
    email         text,
    org_unit_id   uuid REFERENCES org_unit(id),
    active        boolean NOT NULL DEFAULT true,
    UNIQUE (tenant_id, email)
);

CREATE TABLE person_role (
    person_id    uuid NOT NULL REFERENCES person(id),
    role_id      uuid NOT NULL REFERENCES role(id),
    org_unit_id  uuid REFERENCES org_unit(id),
    PRIMARY KEY (person_id, role_id)
);

-- ---------------------------------------------------------------------
-- 1. 標準框架（版本化）
-- ---------------------------------------------------------------------
CREATE TABLE framework (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    uuid REFERENCES tenant(id),          -- NULL = 全域目錄
    code         text NOT NULL,
    name         text NOT NULL,
    publisher    text,
    kind         text NOT NULL
                 CHECK (kind IN ('accreditation','iso','jci','disease_certification','internal','other')),
    -- full: 可存原文；summary: 只存自撰摘要；structure_only: 只存編號/標題結構（如 ISO）
    text_policy  text NOT NULL DEFAULT 'structure_only'
                 CHECK (text_policy IN ('full','summary','structure_only')),
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (tenant_id, code)
);

CREATE TABLE framework_version (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    framework_id    uuid NOT NULL REFERENCES framework(id),
    version_label   text NOT NULL,                    -- 例：'2024', '2015'
    effective_from  date,
    effective_to    date,
    status          text NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','active','retired')),
    source_note     text,                             -- 來源與授權說明
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (framework_id, version_label)
);

-- 條款樹：章 → 節 → 基準 → 項目 → 評量項目
CREATE TABLE requirement (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    framework_version_id  uuid NOT NULL REFERENCES framework_version(id),
    parent_id             uuid REFERENCES requirement(id),
    code                  text NOT NULL,              -- 例：'1.2.3' 或 '7.5.3'
    kind                  text NOT NULL DEFAULT 'item'
                          CHECK (kind IN ('chapter','section','standard','item','criterion')),
    seq                   int  NOT NULL DEFAULT 0,
    title                 text,                       -- 標題（結構資訊）
    body_text             text,                       -- 原文；structure_only 時必須為 NULL
    summary               text,                       -- 自撰摘要／內部解讀
    is_mandatory          boolean NOT NULL DEFAULT false,  -- 必要項目／試評項目等
    attrs                 jsonb NOT NULL DEFAULT '{}'::jsonb, -- 評分方式、適用對象等
    UNIQUE (framework_version_id, code)
);
CREATE INDEX requirement_parent_idx ON requirement(parent_id);

-- 著作權防線：structure_only 框架不得存原文；summary 框架也不得存原文
CREATE FUNCTION enforce_requirement_text_policy() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    policy text;
BEGIN
    SELECT f.text_policy INTO policy
      FROM framework_version fv JOIN framework f ON f.id = fv.framework_id
     WHERE fv.id = NEW.framework_version_id;
    IF policy IN ('structure_only','summary') AND NEW.body_text IS NOT NULL THEN
        RAISE EXCEPTION 'framework text_policy=% forbids storing requirement body_text (code=%)',
            policy, NEW.code USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER requirement_text_policy
    BEFORE INSERT OR UPDATE ON requirement
    FOR EACH ROW EXECUTE FUNCTION enforce_requirement_text_policy();

-- 版本間的條款演變（新版基準與舊版的對應）
CREATE TABLE requirement_lineage (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    from_requirement_id  uuid REFERENCES requirement(id),   -- NULL = 新增
    to_requirement_id    uuid REFERENCES requirement(id),   -- NULL = 刪除
    change_type          text NOT NULL
                         CHECK (change_type IN ('unchanged','modified','renumbered','split','merged','added','removed')),
    note                 text,
    CHECK (from_requirement_id IS NOT NULL OR to_requirement_id IS NOT NULL)
);

-- 跨框架對應（賣點）：例：評鑑 2.1.x ↔ ISO 9001 7.5 ↔ JCI QPS.x
CREATE TABLE crosswalk (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id              uuid REFERENCES tenant(id),       -- NULL = 全域共用對應
    source_requirement_id  uuid NOT NULL REFERENCES requirement(id),
    target_requirement_id  uuid NOT NULL REFERENCES requirement(id),
    relation               text NOT NULL
                           CHECK (relation IN ('equivalent','partial','broader','narrower','related')),
    confidence             numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
    origin                 text NOT NULL DEFAULT 'manual'
                           CHECK (origin IN ('manual','ai','imported')),
    review_status          text NOT NULL DEFAULT 'pending'
                           CHECK (review_status IN ('pending','accepted','rejected')),
    rationale              text,
    reviewed_by            uuid REFERENCES person(id),
    reviewed_at            timestamptz,
    CHECK (source_requirement_id <> target_requirement_id),
    UNIQUE NULLS NOT DISTINCT (tenant_id, source_requirement_id, target_requirement_id)
);

-- ---------------------------------------------------------------------
-- 2. 證據規格（痛點 D 與 C 的核心）
-- ---------------------------------------------------------------------
CREATE TABLE evidence_spec (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id          uuid REFERENCES tenant(id),   -- NULL = 全域範本，院內可複製後調整
    derived_from_id    uuid REFERENCES evidence_spec(id),
    code               text NOT NULL,
    name               text NOT NULL,                -- 例：感染管制委員會會議紀錄
    record_type        text NOT NULL
                       CHECK (record_type IN ('meeting_minutes','training_record','inspection_log',
                                              'indicator_report','audit_report','drill_record',
                                              'maintenance_log','policy','form','other')),
    pdca_phase         text NOT NULL CHECK (pdca_phase IN ('P','D','C','A')),
    -- 頻率：event = 事件驅動（如異常發生時）；once = 一次性
    freq_unit          text NOT NULL
                       CHECK (freq_unit IN ('once','event','day','week','month','quarter','half_year','year')),
    freq_interval      int  NOT NULL DEFAULT 1 CHECK (freq_interval > 0),
    grace_days         int  NOT NULL DEFAULT 0,      -- 逾期寬限（黃燈區間）
    producer_role_id   uuid REFERENCES role(id),     -- 誰產生
    owner_org_unit_id  uuid REFERENCES org_unit(id), -- 哪個單位負責
    retention_months   int,
    description        text,
    version            int  NOT NULL DEFAULT 1,
    status             text NOT NULL DEFAULT 'draft'
                       CHECK (status IN ('draft','active','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (tenant_id, code, version)
);

-- 必備要素：完整性檢查的依據
CREATE TABLE evidence_spec_element (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_spec_id  uuid NOT NULL REFERENCES evidence_spec(id) ON DELETE CASCADE,
    seq               int  NOT NULL DEFAULT 0,
    code              text NOT NULL,
    name              text NOT NULL,                 -- 例：出席人數達法定人數
    description       text,
    check_method      text NOT NULL DEFAULT 'ai_judgement'
                      CHECK (check_method IN ('presence','value','ai_judgement','cross_reference')),
    required          boolean NOT NULL DEFAULT true,
    rule              jsonb NOT NULL DEFAULT '{}'::jsonb,  -- 機器可讀規則，如 {"min_attendance_ratio":0.5}
    UNIQUE (evidence_spec_id, code)
);

-- 條款 ↔ 證據規格（多對多；同一份紀錄可同時滿足多個框架）
CREATE TABLE requirement_evidence_spec (
    requirement_id    uuid NOT NULL REFERENCES requirement(id),
    evidence_spec_id  uuid NOT NULL REFERENCES evidence_spec(id),
    tenant_id         uuid REFERENCES tenant(id),
    note              text,
    PRIMARY KEY (requirement_id, evidence_spec_id)
);

-- ---------------------------------------------------------------------
-- 3. 儲存轉接器與文件（檔案不搬家，系統是覆蓋層）
-- ---------------------------------------------------------------------
CREATE TABLE storage_connector (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES tenant(id),
    kind            text NOT NULL
                    CHECK (kind IN ('builtin','email_inbox','m365','google','nas')),
    name            text NOT NULL,
    config          jsonb NOT NULL DEFAULT '{}'::jsonb,  -- 不放密鑰
    secret_ref      text,                                -- 指向密鑰管理（env/vault）的鍵名
    delta_cursor    text,                                -- M365 delta query token 等
    last_synced_at  timestamptz,
    status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','paused','error')),
    UNIQUE (tenant_id, name)
);

-- 文件／紀錄的「邏輯實體」；metadata 以此為準
CREATE TABLE artifact (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           uuid NOT NULL REFERENCES tenant(id),
    kind                text NOT NULL
                        CHECK (kind IN ('policy','procedure','plan','record','form','report','other')),
    title               text NOT NULL,
    doc_number          text,                        -- 院內文件編號
    org_unit_id         uuid REFERENCES org_unit(id),
    owner_person_id     uuid REFERENCES person(id),
    status              text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('draft','active','superseded','archived')),
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX artifact_tenant_kind_idx ON artifact(tenant_id, kind);

-- 每一個實體版本，指向外部儲存位置
CREATE TABLE artifact_version (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    artifact_id      uuid NOT NULL REFERENCES artifact(id),
    version_no       int  NOT NULL,
    connector_id     uuid NOT NULL REFERENCES storage_connector(id),
    external_id      text NOT NULL,                  -- driveItem id / object key / 路徑
    external_path    text,
    etag             text,
    content_sha256   text,
    mime_type        text,
    size_bytes       bigint,
    source           text NOT NULL DEFAULT 'upload'
                     CHECK (source IN ('upload','email','sync','manual_link')),
    effective_from   date,                           -- 規章生效日
    period_start     date,                           -- 紀錄涵蓋期間（如會議日期）
    period_end       date,
    extract_status   text NOT NULL DEFAULT 'pending'
                     CHECK (extract_status IN ('pending','done','failed','skipped')),
    captured_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (artifact_id, version_no)
);
CREATE INDEX artifact_version_external_idx ON artifact_version(connector_id, external_id);

-- 全文切塊與向量；embedding 維度固定 1024（見 ADR-0004）
CREATE TABLE chunk (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            uuid NOT NULL REFERENCES tenant(id),
    artifact_version_id  uuid NOT NULL REFERENCES artifact_version(id) ON DELETE CASCADE,
    seq                  int  NOT NULL,
    text                 text NOT NULL,
    locator              jsonb NOT NULL DEFAULT '{}'::jsonb,  -- {page, heading, char_start, char_end}
    embedding            vector(1024),
    embedding_model      text,
    UNIQUE (artifact_version_id, seq)
);
CREATE INDEX chunk_embedding_hnsw ON chunk USING hnsw (embedding vector_cosine_ops);
CREATE INDEX chunk_tenant_idx ON chunk(tenant_id);

-- 文件之間的引用（規章引用規章、程序書引用表單）
CREATE TABLE artifact_link (
    from_artifact_id  uuid NOT NULL REFERENCES artifact(id),
    to_artifact_id    uuid NOT NULL REFERENCES artifact(id),
    relation          text NOT NULL CHECK (relation IN ('cites','implements','supersedes','uses_form')),
    PRIMARY KEY (from_artifact_id, to_artifact_id, relation)
);

-- 規章 ↔ 條款（P 層：哪份規章回應哪條要求）
CREATE TABLE artifact_requirement (
    artifact_id     uuid NOT NULL REFERENCES artifact(id),
    requirement_id  uuid NOT NULL REFERENCES requirement(id),
    origin          text NOT NULL DEFAULT 'manual' CHECK (origin IN ('manual','ai')),
    review_status   text NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','accepted','rejected')),
    PRIMARY KEY (artifact_id, requirement_id)
);

-- ---------------------------------------------------------------------
-- 4. AI 服務層的可稽核紀錄（模型閘道、黃金測試集、人審回流）
-- ---------------------------------------------------------------------
CREATE TABLE prompt_template (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code        text NOT NULL,                       -- 例：classify.evidence
    version     int  NOT NULL,
    purpose     text,
    body        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (code, version)
);

CREATE TABLE ai_run (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           uuid REFERENCES tenant(id),
    task                text NOT NULL
                        CHECK (task IN ('embed','classify','completeness','consistency',
                                        'crosswalk','gap','change_impact','extract')),
    model_provider      text NOT NULL,               -- 地端/雲端，閘道可抽換
    model_name          text NOT NULL,
    prompt_template_id  uuid REFERENCES prompt_template(id),
    input_sha256        text,
    input_ref           jsonb NOT NULL DEFAULT '{}'::jsonb,  -- 指向輸入物件，不重複存全文
    output              jsonb,
    status              text NOT NULL DEFAULT 'ok' CHECK (status IN ('ok','error','timeout')),
    error               text,
    latency_ms          int,
    tokens_in           int,
    tokens_out          int,
    created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_run_task_idx ON ai_run(task, created_at);

-- ---------------------------------------------------------------------
-- 5. 證據歸類、完整性、燈號
-- ---------------------------------------------------------------------
-- 一份紀錄被歸類為某證據規格的某期證據
CREATE TABLE evidence_item (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            uuid NOT NULL REFERENCES tenant(id),
    artifact_version_id  uuid NOT NULL REFERENCES artifact_version(id),
    evidence_spec_id     uuid NOT NULL REFERENCES evidence_spec(id),
    org_unit_id          uuid REFERENCES org_unit(id),
    period_start         date,
    period_end           date,
    classified_by        text NOT NULL CHECK (classified_by IN ('ai','rule','human')),
    confidence           numeric(4,3),
    status               text NOT NULL DEFAULT 'suggested'
                         CHECK (status IN ('suggested','confirmed','rejected')),
    ai_run_id            uuid REFERENCES ai_run(id),
    reviewed_by          uuid REFERENCES person(id),
    reviewed_at          timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (artifact_version_id, evidence_spec_id)
);
CREATE INDEX evidence_item_spec_period_idx ON evidence_item(evidence_spec_id, period_start);

-- 逐要素完整性檢查，每一判斷必附出處（citation）
CREATE TABLE element_check (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_item_id  uuid NOT NULL REFERENCES evidence_item(id) ON DELETE CASCADE,
    element_id        uuid NOT NULL REFERENCES evidence_spec_element(id),
    result            text NOT NULL
                      CHECK (result IN ('present','partial','absent','not_applicable','uncertain')),
    citation          jsonb NOT NULL DEFAULT '[]'::jsonb,  -- [{chunk_id, quote, locator}]
    explanation       text,
    ai_run_id         uuid REFERENCES ai_run(id),
    human_result      text CHECK (human_result IN ('present','partial','absent','not_applicable')),
    reviewed_by       uuid REFERENCES person(id),
    reviewed_at       timestamptz,
    UNIQUE (evidence_item_id, element_id)
);

-- 燈號：每個 證據規格 × 單位 × 期間 一筆
CREATE TABLE compliance_status (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         uuid NOT NULL REFERENCES tenant(id),
    evidence_spec_id  uuid NOT NULL REFERENCES evidence_spec(id),
    org_unit_id       uuid REFERENCES org_unit(id),
    period_start      date NOT NULL,
    period_end        date NOT NULL,
    light             text NOT NULL CHECK (light IN ('green','yellow','red','grey')),
    reason            jsonb NOT NULL DEFAULT '{}'::jsonb,  -- {missing:[], overdue_days:.., incomplete_elements:[]}
    computed_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (evidence_spec_id, org_unit_id, period_start)
);

-- ---------------------------------------------------------------------
-- 6. 稽核發現（Find → Explain → Grade）、變更影響、PDCA 閉環
-- ---------------------------------------------------------------------
CREATE TABLE finding (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id                   uuid NOT NULL REFERENCES tenant(id),
    kind                        text NOT NULL
                                CHECK (kind IN ('consistency','completeness','gap','change_impact')),
    requirement_id              uuid REFERENCES requirement(id),
    evidence_spec_id            uuid REFERENCES evidence_spec(id),
    policy_artifact_version_id  uuid REFERENCES artifact_version(id),  -- 規章（說的）
    record_artifact_version_id  uuid REFERENCES artifact_version(id),  -- 紀錄（做的）
    find_summary                text NOT NULL,       -- Find
    explanation                 text,                -- Explain
    grade                       text NOT NULL        -- Grade
                                CHECK (grade IN ('critical','major','minor','observation')),
    citations                   jsonb NOT NULL DEFAULT '[]'::jsonb,
    ai_run_id                   uuid REFERENCES ai_run(id),
    status                      text NOT NULL DEFAULT 'open'
                                CHECK (status IN ('open','confirmed','dismissed','resolved')),
    reviewed_by                 uuid REFERENCES person(id),
    reviewed_at                 timestamptz,
    created_at                  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX finding_tenant_status_idx ON finding(tenant_id, status);

-- 變更事件：規章改版、標準框架改版
CREATE TABLE change_event (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             uuid REFERENCES tenant(id),
    kind                  text NOT NULL CHECK (kind IN ('artifact_revised','framework_revised','spec_revised')),
    artifact_version_id   uuid REFERENCES artifact_version(id),
    framework_version_id  uuid REFERENCES framework_version(id),
    evidence_spec_id      uuid REFERENCES evidence_spec(id),
    summary               text,
    detected_at           timestamptz NOT NULL DEFAULT now()
);

-- 變更影響：源頭預防漂移
CREATE TABLE change_impact (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    change_event_id  uuid NOT NULL REFERENCES change_event(id) ON DELETE CASCADE,
    target_type      text NOT NULL CHECK (target_type IN ('requirement','evidence_spec','artifact')),
    target_id        uuid NOT NULL,
    impact_level     text NOT NULL CHECK (impact_level IN ('high','medium','low')),
    explanation      text,
    ai_run_id        uuid REFERENCES ai_run(id),
    status           text NOT NULL DEFAULT 'open'
                     CHECK (status IN ('open','acknowledged','handled','dismissed'))
);

-- PDCA 的 A：改善行動，必須以新證據驗證後才關閉
CREATE TABLE action_item (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id                 uuid NOT NULL REFERENCES tenant(id),
    finding_id                uuid REFERENCES finding(id),
    change_impact_id          uuid REFERENCES change_impact(id),
    title                     text NOT NULL,
    owner_person_id           uuid REFERENCES person(id),
    org_unit_id               uuid REFERENCES org_unit(id),
    due_date                  date,
    status                    text NOT NULL DEFAULT 'open'
                              CHECK (status IN ('open','in_progress','done','verified','cancelled')),
    verification_evidence_id  uuid REFERENCES evidence_item(id),
    verified_by               uuid REFERENCES person(id),
    verified_at               timestamptz,
    created_at                timestamptz NOT NULL DEFAULT now(),
    CHECK (status <> 'verified' OR verification_evidence_id IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- 7. 人審回流與黃金測試集
-- ---------------------------------------------------------------------
CREATE TABLE human_review (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id          uuid NOT NULL REFERENCES tenant(id),
    subject_type       text NOT NULL
                       CHECK (subject_type IN ('evidence_item','element_check','finding',
                                               'crosswalk','change_impact','artifact_requirement')),
    subject_id         uuid NOT NULL,
    ai_run_id          uuid REFERENCES ai_run(id),
    verdict            text NOT NULL CHECK (verdict IN ('accept','edit','reject')),
    correction         jsonb,
    comment            text,
    reviewer_id        uuid NOT NULL REFERENCES person(id),
    promote_to_golden  boolean NOT NULL DEFAULT false,
    created_at         timestamptz NOT NULL DEFAULT now()
);

-- 黃金測試集：去識別化後的固定案例，換模型/改 prompt 前必跑
CREATE TABLE golden_case (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task              text NOT NULL,
    name              text NOT NULL,
    input             jsonb NOT NULL,
    expected          jsonb NOT NULL,
    source            text NOT NULL DEFAULT 'curated' CHECK (source IN ('curated','human_review')),
    human_review_id   uuid REFERENCES human_review(id),
    deidentified      boolean NOT NULL DEFAULT false,
    active            boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE golden_eval (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    golden_case_id  uuid NOT NULL REFERENCES golden_case(id),
    ai_run_id       uuid NOT NULL REFERENCES ai_run(id),
    passed          boolean NOT NULL,
    score           numeric,
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 8. 通知（轉接器：email 為基本款；LINE/Teams 選配）與稽核軌跡
-- ---------------------------------------------------------------------
CREATE TABLE notification (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            uuid NOT NULL REFERENCES tenant(id),
    channel              text NOT NULL CHECK (channel IN ('email','in_app','line','teams')),
    recipient_person_id  uuid REFERENCES person(id),
    subject              text,
    body                 text,
    related_type         text,
    related_id           uuid,
    status               text NOT NULL DEFAULT 'queued'
                         CHECK (status IN ('queued','sent','failed','cancelled')),
    scheduled_at         timestamptz NOT NULL DEFAULT now(),
    sent_at              timestamptz
);

CREATE TABLE audit_log (
    id               bigserial PRIMARY KEY,
    tenant_id        uuid REFERENCES tenant(id),
    actor_person_id  uuid REFERENCES person(id),
    actor_kind       text NOT NULL DEFAULT 'person' CHECK (actor_kind IN ('person','system','ai')),
    action           text NOT NULL,
    entity_type      text NOT NULL,
    entity_id        uuid,
    diff             jsonb,
    at               timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 9. 關係圖視圖：把各表的關聯攤平成邊，供圖譜查詢與視覺化
-- ---------------------------------------------------------------------
CREATE VIEW v_graph_edge AS
    SELECT 'requirement'::text AS src_type, r.parent_id AS src_id,
           'requirement'::text AS dst_type, r.id AS dst_id, 'contains'::text AS relation
      FROM requirement r WHERE r.parent_id IS NOT NULL
UNION ALL
    SELECT 'requirement', c.source_requirement_id, 'requirement', c.target_requirement_id,
           'crosswalk:' || c.relation
      FROM crosswalk c WHERE c.review_status <> 'rejected'
UNION ALL
    SELECT 'requirement', l.from_requirement_id, 'requirement', l.to_requirement_id,
           'lineage:' || l.change_type
      FROM requirement_lineage l
     WHERE l.from_requirement_id IS NOT NULL AND l.to_requirement_id IS NOT NULL
UNION ALL
    SELECT 'requirement', res.requirement_id, 'evidence_spec', res.evidence_spec_id, 'requires_evidence'
      FROM requirement_evidence_spec res
UNION ALL
    SELECT 'artifact', ar.artifact_id, 'requirement', ar.requirement_id, 'addresses'
      FROM artifact_requirement ar WHERE ar.review_status <> 'rejected'
UNION ALL
    SELECT 'artifact', al.from_artifact_id, 'artifact', al.to_artifact_id, al.relation
      FROM artifact_link al
UNION ALL
    SELECT 'artifact_version', ei.artifact_version_id, 'evidence_spec', ei.evidence_spec_id, 'evidences'
      FROM evidence_item ei WHERE ei.status <> 'rejected';

COMMIT;
