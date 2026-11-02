# 知識核心資料模型

| 項目 | 內容 |
|---|---|
| 文件編號 | AIKM-DES-001 |
| 版次 | 0.1（草稿；v0.2 的修訂項目見文末） |
| 狀態 | 草稿 |
| 日期 | 2026-11-03 |

實作：[`db/migrations/0001_knowledge_core.sql`](../../db/migrations/0001_knowledge_core.sql)　示範：[`db/seed/0001_demo.sql`](../../db/seed/0001_demo.sql)　測試：[`db/tests/smoke.sql`](../../db/tests/smoke.sql)

> v0.1 是在需求討論之前產出的草稿。已驗證可以在 PostgreSQL 16 + pgvector 上執行，並通過冒煙測試；但尚未反映 2026-11-03 的需求決策。

所有表放在 `km` schema。

## 一張圖看懂

```
framework ─┬─ framework_version ── requirement (樹) ──┬── crosswalk ──► requirement（他框架）
           │                         │                └── requirement_lineage ──► requirement（新版）
           │                         │
           │               requirement_evidence_spec (多對多)
           │                         │
           │                   evidence_spec ── evidence_spec_element（必備要素）
           │                         │
 artifact ── artifact_version ── evidence_item ── element_check
 (規章/紀錄)   (指向外部檔案)          │
     │              │                 └──► compliance_status（燈號：規格×單位×期間）
     │            chunk（全文切塊＋向量）
     │
     └── artifact_requirement ──► requirement（規章回應哪條要求）

finding（Find→Explain→Grade）──► action_item（PDCA，需新證據驗證）
change_event ──► change_impact ──► action_item
ai_run ◄── 所有 AI 產出都回指；human_review ──► golden_case ──► golden_eval
```

## 分區說明

### 1. 標準框架（版本化）
- `framework`：一個標準體系（醫院評鑑、ISO 9001、JCI…）。`tenant_id` NULL 為全域目錄，院內自訂框架則帶 tenant。
- `framework.text_policy`：**著作權防線**。
  - `full`：可存原文（如公開法規、院內自訂）
  - `summary`：只存自撰摘要
  - `structure_only`：只存編號與標題（ISO 系列）
  - 由 trigger `requirement_text_policy` 強制：非 `full` 的框架寫入 `body_text` 會被拒絕。
- `framework_version`：每次改版一筆；條款掛在版本下。
- `requirement`：條款樹（章／節／基準／項目／評量項目），`code` 在版本內唯一。
- `requirement_lineage`：新舊版條款對應（未變、修改、重編號、拆分、合併、新增、刪除）——評鑑改版時用來搬移證據對應。
- `crosswalk`：**跨框架對應（賣點）**，含關係型態（等同／部分／較廣／較窄／相關）、信心值、來源（人工／AI／匯入）與審核狀態。

### 2. 證據規格（核心痛點 D 與 C）
把每條要求拆成「什麼紀錄、多久一次、誰產生、需含哪些要素」：

| 問題 | 欄位 |
|---|---|
| 什麼紀錄 | `evidence_spec.record_type`、`name` |
| 多久一次 | `freq_unit` × `freq_interval`、`grace_days` |
| 誰產生 | `producer_role_id`、`owner_org_unit_id` |
| 需含哪些要素 | `evidence_spec_element`（`check_method`、`rule`） |
| 屬 PDCA 哪段 | `pdca_phase` |

- `evidence_spec` 可為全域範本（`tenant_id` NULL），院內以 `derived_from_id` 複製後調整。
- `requirement_evidence_spec` 是多對多：**一份會議紀錄同時滿足評鑑與 ISO 的條款**，這就是跨框架省工的地方。

### 3. 文件與儲存轉接器
- `storage_connector`：轉接器設定，不存密鑰（只存 `secret_ref`）。M365 的 delta token 存 `delta_cursor`。
- `artifact`：邏輯文件（規章、程序書、紀錄、表單…），metadata 以此為準。
- `artifact_version`：實體版本，指向外部儲存（`external_id`、`etag`、`content_sha256`）。紀錄類以 `period_start/end` 標示涵蓋期間；規章類以 `effective_from` 標示生效日。
- `chunk`：抽出的文字切塊＋向量＋`locator`（頁碼、段落），供檢索與出處引用。
- `artifact_link`、`artifact_requirement`：文件間引用、規章對應條款。

### 4. 證據與燈號
- `evidence_item`：某份紀錄被歸類為某證據規格的某一期證據（AI 建議 → 人確認）。
- `element_check`：逐要素完整性判斷，**每一判斷都必須附 citation**；人可覆寫 `human_result`。
- `compliance_status`：每個「證據規格 × 單位 × 期間」一個燈號。
  - 綠：該期證據已確認且必備要素齊全
  - 黃：在寬限期內未到／要素部分缺漏／尚待人審
  - 紅：逾期未交或必備要素缺漏
  - 灰：不適用或尚未到期
- 一鍵佐證清單 = 依條款 → `requirement_evidence_spec` → `evidence_item(confirmed)` → `artifact_version` 展開。

### 5. 稽核、變更、PDCA
- `finding`：Find（`find_summary`）→ Explain（`explanation`）→ Grade（`grade`），同時指向「規章說的」與「紀錄做的」兩個版本。
- `change_event` → `change_impact`：規章或框架改版時，列出受影響的條款、證據規格、文件——源頭預防漂移。
- `action_item`：改善行動。**資料庫層強制**：狀態為 `verified` 時必須有 `verification_evidence_id`（以新證據證明改善，閉環）。

### 6. AI 留痕與品質
- `prompt_template`：prompt 版本化。
- `ai_run`：每次模型呼叫一筆（供應商、模型、prompt 版本、輸入雜湊、輸出、延遲、token）。輸入只存參照，不重複存全文。
- `human_review`：人審結果（接受／修改／拒絕），可標記 `promote_to_golden`。
- `golden_case`／`golden_eval`：黃金測試集與每次評測結果，換模型或改 prompt 前必跑。

### 7. 關係圖
`v_graph_edge` 把各表的關聯攤平成 `(src_type, src_id, dst_type, dst_id, relation)`。MVP 階段用 SQL／遞迴 CTE 走圖即可，不另外引入圖資料庫。

## 刻意延後的設計
- **Row-Level Security**：所有租戶表已帶 `tenant_id`，多院產品版時再啟用 RLS 政策。
- **權限模型**（誰能看哪些文件）：MVP-0 單院、少數使用者，先用角色粗分；試點前補。
- **向量維度**：先固定 1024；若換 embedding 模型維度不同，新增欄位或重建（[ADR-0018](../adr/0018-vector-1024.md)）。
- **全文檢索**：中文分詞方案（如 zhparser / pg_bigm）待評估，MVP-0 先靠向量＋關鍵字 ILIKE。

## 待確認問題
1. 評鑑基準的「評量項目」與「評分說明」要拆到 `criterion` 層級，還是放 `attrs`？
2. 燈號的期間是依日曆季／年，還是依評鑑週期（例如評鑑前 N 年）滾動？可能兩者都要。
3. 單位（`org_unit`）以院內組織圖匯入，還是先手動維護？

## v0.2 待修訂項目（依 2026-11-03 決策）

| # | 修訂 | 來源 |
|---|---|---|
| 1 | 新增 `membership`（人員 × 單位 × 身分 × 有效期間）；取消 `person.org_unit_id` 的單一隸屬 | ADR-0010、ORG-13 |
| 2 | `org_unit.kind` 增加 `campus`（院區）、`group`（專案小組）；委員會、小組可以不掛在組織樹上 | ORG-01、ORG-14 |
| 3 | 新增設定表 `setting`（範圍 × 設定項 → 設定值），支援分層繼承 | ORG-03 |
| 4 | 新增 `evidence_task`（證據規格 × 單位 × 期間 → 任務、期限、狀態），以及待歸類區的處理時限 | TASK-01、TASK-10 |
| 5 | 儲存層改為以內容雜湊值定址的 `blob`；新增 `archive_copy`（副本存放轉接器、位置、鎖定期限）；`storage_connector.kind` 增加副本存放類型 | ADR-0004、DOC-04、DOC-10 |
| 6 | 文件管制：`document_control`（編號、版次、生效日、作廢、審查週期）、`workflow_template`／`workflow_step`（可以包含外部步驟，例如公文）、`workflow_instance` | ADR-0012、DCT-* |
| 7 | 簽核：`signoff`（對象、人員、時間、意見、內容雜湊值、是否有效、代理人） | ADR-0016、SIGN-* |
| 8 | `human_review` 增加 `content_sha256` | REV-05 |
| 9 | Agent：`agent_run`／`agent_step`（服務帳號、工具呼叫、產出建議） | ADR-0014、MON-05 |
| 10 | 導入建置：證據規格草稿的來源（辦法版本 × 原文出處）、單位確認清單 | BOOT-02～05 |
| 11 | 領域套件：`domain_pack`，讓框架、證據規格範本、單位範本可以追溯到套件與版本 | ADR-0013 |
| 12 | 舊 KM 匯入：`artifact_version` 增加原始路徑、原始標籤等線索欄位 | TASK-12 |
| 13 | 條款準備度簽署與燈號並列 | SIGN-06 |
| 14 | 稽核軌跡在資料庫層設為只能新增（撤銷 UPDATE／DELETE 權限，或用觸發器阻擋） | AUD-02 |
| 15 | 頻率單位新增 `shift`（每班）；證據規格同時有「頻率」與「完成時限」（例：每季開會、會後 14 日內核定） | AIKM-TST-001 |
| 16 | 新增「辦法問題」：抽取時發現的矛盾、不明確、缺漏，可以轉為文管修訂建議 | AIKM-TST-001、情境 1 |
| 17 | 證據規格的適用單位：一份規格、多個單位各自產生 | 情境 1 |
