# 01 · 系統架構

## 五層架構

```
┌──────────────────────────────────────────────────────────────┐
│ ① 使用介面    儀表板（燈號）· 一鍵佐證清單 · 審核佇列 · 條款瀏覽 │
├──────────────────────────────────────────────────────────────┤
│ ② 應用模組    證據歸類 · 完整性檢查 · 一致性稽核 · 對應與缺口    │
│              · 變更影響 · PDCA 閉環                            │
├──────────────────────────────────────────────────────────────┤
│ ③ AI 服務層   模型閘道（可抽換，預設地端）· Prompt 版本管理      │
│              · 黃金測試集 · 人審回流 · ai_run 全程留痕          │
├──────────────────────────────────────────────────────────────┤
│ ④ 知識核心    標準框架（版本化）→ 條款樹 → 證據規格 → 證據      │
│              關係圖（v_graph_edge）· 向量（pgvector）          │
│              Postgres = metadata 唯一真實來源                  │
├──────────────────────────────────────────────────────────────┤
│ ⑤ 轉接器      儲存：內建 / M365 / Google / NAS                  │
│              證據入口：上傳 / 專用收件信箱 / 同步               │
│              通知：Email / LINE / Teams                        │
└──────────────────────────────────────────────────────────────┘
```

## 核心原則

1. **檔案不搬家，系統是覆蓋層。** 實體檔案留在醫院原本的儲存（O365、NAS…）。系統只存「指向它的參照」（`artifact_version.connector_id + external_id + etag`）與抽出的文字切塊。
2. **Metadata 以系統資料庫為準。** 外部儲存的資料夾結構、檔名不是真相來源；歸類、期間、單位、對應條款都存在 `km` schema。
3. **基本款零整合。** 內建上傳＋專用收件信箱＋Email 提醒就能完整運作。所有整合都是選配轉接器，不能成為上線前提。
4. **AI 只建議、人確認。** 所有 AI 產出狀態起始為 `suggested`／`pending`，附出處（citation），由人審確認；人審結果回流成黃金測試集。
5. **模型可抽換。** 應用模組只呼叫模型閘道的「任務介面」（classify / completeness / consistency …），不綁特定模型供應商。換模型或改 prompt 前，必跑黃金測試集。
6. **地端優先。** 病人資料與院內文件預設不出院；雲端模型為選配，且需去識別化與院方書面同意。

## 轉接器介面（概念）

| 轉接器 | 必要方法 | 基本款實作 | 選配實作 |
|---|---|---|---|
| StorageAdapter | `list_changes(cursor)`、`fetch(external_id)`、`stat(external_id)` | 內建（本機/物件儲存） | M365 Graph（Sites.Selected + delta query）、Google Drive、NAS（SMB/WebDAV） |
| IntakeAdapter | `poll() → [IncomingItem]` | 網頁上傳、專用收件信箱（IMAP） | M365 資料夾監看、LINE |
| NotifyAdapter | `send(recipient, message)` | Email（SMTP） | LINE、Teams |

M365 原則：只申請 `Sites.Selected`（由院方 IT 授權特定網站），不申請整個租戶讀取權；以 delta query 增量同步，`delta_cursor` 存在 `storage_connector`。

## AI 模組對應資料表

| 模組 | 輸入 | 輸出資料表 |
|---|---|---|
| 證據歸類 | 新進 `artifact_version` 的切塊 | `evidence_item`（suggested） |
| 完整性檢查 | `evidence_item` + `evidence_spec_element` | `element_check` → `compliance_status` |
| 一致性稽核（Find → Explain → Grade） | 規章版本 × 紀錄版本 | `finding`（kind=consistency） |
| 評鑑對應與缺口 | 條款 × 規章／證據規格 | `artifact_requirement`、`crosswalk`、`finding`（gap） |
| 變更影響 | `change_event` | `change_impact` |
| PDCA 閉環 | `finding`／`change_impact` | `action_item`（需新證據驗證才能 verified） |

## 技術選型（MVP-0 預設，可再議）

- 資料庫：PostgreSQL 16 + pgvector（已定）
- 後端：Python（FastAPI）——文件解析、AI 生態系最完整
- 文件解析：PDF / DOCX / 掃描檔 OCR（地端）
- 模型：地端 LLM 與 embedding（經閘道），維度 1024（見 ADR-0004）
- 前端：MVP-0 先用伺服器端渲染的簡單頁面，不做 SPA
