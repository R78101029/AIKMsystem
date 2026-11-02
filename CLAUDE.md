# CLAUDE.md

給在此程式庫工作的 AI 助手與新進工程師的速覽。

## 先讀這些
1. `docs/01-requirements/requirements.md`：需求（REQ 編號）
2. `docs/adr/README.md`：已定的架構決策
3. `docs/02-architecture/architecture.md`：六層架構
4. `docs/discussions/`：最近的討論紀錄

## 開發流程（ISO/IEC 29110，見 docs/09-quality/development-process.md）
- 所有變更都要引用需求編號或 ADR；變更架構決策時新增 ADR，不改寫舊的。
- **每次重要討論結束後，把摘要寫入 `docs/discussions/YYYY-MM-DD-主題.md`。**
- 正式文件的開頭要有表格：文件編號、版次、狀態、日期。
- 專案負責人說「先討論、先不要動手」時，只討論，不改檔案。

## 不可違反的規則
- 層次只能由上往下呼叫：Agent → 應用模組 → AI 服務層 → 核心 → 轉接器；應用模組不直接呼叫模型。
- 原檔不搬家；確認的證據另存不可修改的副本（ADR-0004）。
- 非 `full` 的框架不可以存條文原文（資料庫觸發器強制）。
- AI 產出必須附出處，預設為待審；每次模型呼叫都留紀錄。
- 真實院內資料、合約、密鑰不可以進入程式庫；seed 和測試只用模擬資料。
- 已合併的資料庫遷移腳本不可以修改，只能新增。
- 核心不可以寫死醫療專有名詞，一律放在領域套件裡（ADR-0013）。
- 文件用繁體中文；程式碼、資料庫、API 的命名用英文。

## 常用指令
- 驗證資料模型（不需要 Docker）：`./tools/db-test-local.sh`
- Docker：`cp .env.example .env && make db-up db-migrate db-seed db-test`
