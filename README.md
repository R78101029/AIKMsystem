# AIKMsystem · 評鑑導向 KM＋AI 稽核系統

醫療機構的「標準框架導向」知識管理與 AI 稽核覆蓋層。檔案留在院方既有儲存（Office 365、NAS…），系統負責把**條款 → 證據規格 → 實際紀錄**串起來，用 AI 做歸類、完整性檢查與規章／紀錄一致性比對，輸出燈號與一鍵佐證清單。

痛點在 **D（執行）與 C（查核）**，不是 P（寫規章）。

## 文件導覽

| 文件 | 內容 |
|---|---|
| [docs/00-handoff.md](docs/00-handoff.md) | 專案起點：討論結論原文 |
| [docs/01-architecture.md](docs/01-architecture.md) | 五層架構、轉接器、AI 模組 |
| [docs/02-data-model.md](docs/02-data-model.md) | 知識核心資料模型 v0.1 |
| [docs/03-mvp0-scope.md](docs/03-mvp0-scope.md) | MVP-0 範圍與第一類證據選擇 |
| [docs/04-business-compliance.md](docs/04-business-compliance.md) | 智財、利益迴避、著作權、資安檢核表 |
| [docs/deployment.md](docs/deployment.md) | 部署文件（從第一天維護） |
| [docs/adr/](docs/adr/README.md) | 架構決策紀錄 |

## 目前進度

- [x] 知識核心資料模型 v0.1（`db/migrations/0001_knowledge_core.sql`）
- [x] 虛構示範資料與冒煙測試
- [ ] 確認 MVP-0 第一類證據（建議：委員會會議紀錄）
- [ ] MVP-0 應用程式：上傳 → 解析 → AI 歸類／完整性／一致性 → 人審 → 燈號

## 快速驗證資料模型

```bash
./scripts/db-test-local.sh
```

（需本機 PostgreSQL 16 + pgvector；或用 Docker，見 [deployment.md](docs/deployment.md)）

## 里程碑

| 階段 | 工作量 | 內容 |
|---|---|---|
| MVP-0 | 約 1.5 人月 | 一類證據跑通全流程，自己做 |
| MVP-1 | 約 3–4 人月 | 安南免費試點，找第一位工程師 |
| 產品版 | 約 8–12 人月 | 多院、M365／Google／NAS 轉接器、跨框架 |
