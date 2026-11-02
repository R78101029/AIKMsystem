# 變更紀錄

格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號採語意化版本。

## [未發行]

### 新增
- 需求規格書 v0.1（`docs/01-requirements/requirements.md`）
- 架構決策紀錄 ADR-0001～0019
- 2026-11-03 需求與架構討論紀錄
- 專案計畫、開發程序（ISO/IEC 29110）、需求追溯矩陣、導入檢核表
- 架構文件 v0.2（六層架構，新增 Agent 編排層）
- PR 範本、需求變更 Issue 範本
- 對外溝通紀錄：2026-11-03 給文管中心與資訊室的系統示意頁（`docs/00-project/communications/`）

### 變更
- 文件依 ISO/IEC 29110 生命週期重整至 `docs/00-project` ～ `docs/09-quality`
- `docker-compose.yml` 移至 `deploy/docker-compose.dev.yml`；`scripts/` 改名為 `tools/`

### 備註
- 資料模型仍為 v0.1 草稿，v0.2 的修訂項目列於 `docs/03-design/data-model.md`
