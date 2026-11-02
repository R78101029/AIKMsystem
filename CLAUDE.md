# CLAUDE.md

給在此 repo 工作的 AI 助手與新進工程師的速覽。完整背景見 `docs/00-handoff.md`。

## 專案一句話
醫療機構「標準框架導向」KM＋AI 稽核覆蓋層：條款 → 證據規格 → 紀錄，AI 歸類／完整性／一致性，人審後出燈號與佐證清單。

## 不可違反的規則
- **檔案不搬家**：不要設計把院方檔案複製進系統當正本的功能；只存參照與抽出文字。
- **標準條文著作權**：非 `full` 框架不得存 `body_text`（DB trigger 強制）。seed 與測試只用虛構資料。
- **真實院內資料不進版控**：`data/`、`private/` 已 gitignore。
- **AI 產出必附出處、預設待人審**；每次模型呼叫寫 `ai_run`。
- **已合併的 migration 不改**，只新增 `db/migrations/000N_*.sql`。
- 範圍限醫療機構。
- 文件以繁體中文撰寫。

## 常用指令
- 驗證資料模型（無 Docker）：`./scripts/db-test-local.sh`
- Docker：`make db-up db-migrate db-seed db-test`

## 結構
- `db/migrations/` 資料模型（`km` schema）
- `db/seed/` 虛構示範資料
- `db/tests/` SQL 冒煙測試
- `docs/` 架構、資料模型、MVP 範圍、合規、部署、ADR
