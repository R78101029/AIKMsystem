-- 資料模型冒煙測試：需先套用 migrations 與 seed。任何失敗會 RAISE 並以非零結束。
\set ON_ERROR_STOP on
SET search_path = km, public;

-- 1. 著作權防線：structure_only 框架不得寫入原文
DO $$
BEGIN
    BEGIN
        UPDATE requirement SET body_text = '任何原文'
         WHERE id = '00000000-0000-0000-0012-000000000003';
        RAISE EXCEPTION 'FAIL: structure_only framework accepted body_text';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'ok: text_policy trigger blocks body_text';
    END;
END $$;

-- 2. 跨框架：同一證據規格同時滿足兩個框架的條款
DO $$
DECLARE n int;
BEGIN
    SELECT count(DISTINCT fv.framework_id) INTO n
      FROM requirement_evidence_spec res
      JOIN requirement r ON r.id = res.requirement_id
      JOIN framework_version fv ON fv.id = r.framework_version_id
     WHERE res.evidence_spec_id = '00000000-0000-0000-0020-000000000001';
    IF n <> 2 THEN RAISE EXCEPTION 'FAIL: expected 2 frameworks, got %', n; END IF;
    RAISE NOTICE 'ok: one evidence spec serves % frameworks', n;
END $$;

-- 3. 關係圖視圖可查詢，且包含 crosswalk 與 evidences 邊
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM v_graph_edge
     WHERE relation IN ('crosswalk:partial','evidences','requires_evidence','addresses','contains');
    IF n < 5 THEN RAISE EXCEPTION 'FAIL: graph edges too few: %', n; END IF;
    RAISE NOTICE 'ok: v_graph_edge returns % edges', n;
END $$;

-- 4. PDCA：未附驗證證據的改善行動不得標為 verified
DO $$
BEGIN
    BEGIN
        INSERT INTO action_item (tenant_id, title, status)
        VALUES ('00000000-0000-0000-0000-000000000001', 'test', 'verified');
        RAISE EXCEPTION 'FAIL: verified action without evidence accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'ok: action_item requires verification evidence';
    END;
END $$;

-- 5. pgvector：寫入 1024 維向量並做餘弦相似度查詢
DO $$
DECLARE d float8;
BEGIN
    INSERT INTO chunk (tenant_id, artifact_version_id, seq, text, embedding, embedding_model)
    SELECT '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0032-000000000002',
           999, 'smoke', array_fill(0.1::real, ARRAY[1024])::vector, 'smoke';
    SELECT embedding <=> array_fill(0.1::real, ARRAY[1024])::vector INTO d
      FROM chunk WHERE seq = 999;
    IF d > 1e-6 THEN RAISE EXCEPTION 'FAIL: cosine distance %', d; END IF;
    DELETE FROM chunk WHERE seq = 999;
    RAISE NOTICE 'ok: pgvector cosine search works';
END $$;

\echo 'ALL SMOKE TESTS PASSED'
