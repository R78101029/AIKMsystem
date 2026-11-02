# AIKMsystem · 評鑑導向 KM＋AI 稽核系統

醫療機構「標準框架導向」的知識管理與 AI 稽核覆蓋層。

- 以**條款**為錨點，以**證據規格**為翻譯層，把「辦法（P）→ 應產生的紀錄（D/C）→ 實際紀錄」串起來。
- AI 負責歸類、要素完整性檢查，以及辦法與紀錄的一致性稽核。
- 輸出燈號、準備度與一鍵佐證清單。
- 導入時，由 Agent 從辦法中自動整理出文件架構，取代逐單位訪談。

痛點在 **D（執行）與 C（查核）**，不是 P（寫規章）。

## 目前階段：需求分析

| 文件 | 內容 |
|---|---|
| [需求規格書](docs/01-requirements/requirements.md) | 角色、功能需求、非功能需求（REQ 編號） |
| [系統架構](docs/02-architecture/architecture.md) | 六層架構、轉接器、模組 |
| [架構決策紀錄](docs/adr/README.md) | ADR-0001～0019 |
| [專案計畫](docs/00-project/project-plan.md) | 里程碑、下一步、風險 |
| [市場與競品分析](docs/00-project/market-analysis.md) | 台灣同類產品、差異化、法規趨勢（內部文件） |
| [討論紀錄](docs/discussions/) | 依日期整理 |
| [開發程序](docs/09-quality/development-process.md) | ISO/IEC 29110 |
| [資料夾結構](docs/02-architecture/repository-structure.md) | 程式庫結構說明 |
| [交接摘要](docs/00-project/handoff.md) | 專案起點 |
| [對外溝通紀錄](docs/00-project/communications/README.md) | 給院內單位的說明資料存檔（含系統示意頁） |

## 快速驗證資料模型（v0.1 草稿）

需要本機已安裝 PostgreSQL 16 與 pgvector：

```bash
./tools/db-test-local.sh
```

使用 Docker 的方式見[部署文件](docs/06-deployment/deployment.md)。

## 里程碑

| 階段 | 工作量 | 內容 |
|---|---|---|
| MVP-0 | 約 2 人月 | 匯入辦法 → 證據規格 → 任務 → 上傳 → AI 檢查與一致性稽核 → 人審 → 燈號，使用模擬資料 |
| MVP-1 | 待重估 | 安南免費試點：文管、簽核、導入與監控 Agent、O365、OIDC |
| 產品版 | 待重估 | 多院、跨框架、其他轉接器 |
