# 架構決策紀錄（ADR）

每個決策一個檔案，編號不重複使用。決策被推翻時，新增一個 ADR 並註明取代關係，舊檔只更新狀態，不刪除。

> 2026-11-03 整併說明：初版草稿（commit `3fcdb2f`）的 6 個 ADR 已依需求討論的結果整併重編為下列清單，原始內容可以從 git 歷史查閱。

| 編號 | 決策 | 狀態 |
|---|---|---|
| [ADR-0001](0001-requirement-as-anchor.md) | 以條款為錨點，證據規格為翻譯層 | 已採納 |
| [ADR-0002](0002-framework-generalization.md) | 標準框架泛化；證據規格與條款多對多 | 已採納 |
| [ADR-0003](0003-copyright-enforced-in-db.md) | 標準條文著作權由資料庫層強制 | 已採納 |
| [ADR-0004](0004-overlay-and-immutable-archive.md) | 原檔不搬家；確認的證據另存不可修改的副本 | 已採納 |
| [ADR-0005](0005-ai-task-interface.md) | AI 任務介面解耦；模型轉接器與路由 | 已採納 |
| [ADR-0006](0006-ai-suggest-human-review.md) | AI 產出一律「建議 → 人審」，附出處、全程留痕 | 已採納 |
| [ADR-0007](0007-iso29110-process.md) | 開發流程依 ISO/IEC 29110 | 已採納 |
| [ADR-0008](0008-single-repo-agents.md) | 單一程式庫；Agent 為模組，以授權開關區隔 | 已採納 |
| [ADR-0009](0009-language-convention.md) | 語言慣例：文件繁中、程式英文 | 已採納 |
| [ADR-0010](0010-membership-permission.md) | 權限採成員關係模式 | 已採納 |
| [ADR-0011](0011-auth-adapter.md) | 登入做成轉接器 | 已採納 |
| [ADR-0012](0012-document-control-modes.md) | 文管支援外部、內建兩種模式；生效流程可以設定 | 已採納 |
| [ADR-0013](0013-industry-neutral-domain-packs.md) | 架構不分產業（領域套件），商業先專注醫療 | 已採納 |
| [ADR-0014](0014-agent-layer.md) | 新增 Agent 編排層：導入分析與稽核監控 | 已採納 |
| [ADR-0015](0015-workflow-enforced-linkage.md) | 以流程強制關聯；未確認的檔案不列入佐證 | 已採納 |
| [ADR-0016](0016-readiness-and-signoff.md) | 準備度由系統客觀計算；簽核是主管認可，與燈號分開 | 已採納 |
| [ADR-0017](0017-legacy-backlog-strategy.md) | D/C 存量策略：以某日為界 | 已採納 |
| [ADR-0018](0018-vector-1024.md) | 向量維度暫定 1024，存放於 pgvector | 暫定 |
| [ADR-0019](0019-mvp0-scope.md) | MVP-0 範圍：約 2 人月 | 已採納 |
