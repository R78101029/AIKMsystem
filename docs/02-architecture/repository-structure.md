# 程式庫資料夾結構

| 項目 | 內容 |
|---|---|
| 版次 | 0.1 |
| 狀態 | 已確認（2026-11-03 討論） |

標示 ✅ 的資料夾已經建立；標示 ⏳ 的資料夾在開始實作時才建立，避免出現空資料夾。

```
AIKMsystem/
├── README.md                    專案入口
├── CHANGELOG.md            ✅   版本變更紀錄
├── CLAUDE.md                    AI 助手協作規則
│
├── docs/                   ✅   文件（依 ISO/IEC 29110 生命週期編號）
│   ├── 00-project/              專案計畫、交接摘要、合規檢核表
│   ├── 01-requirements/         需求規格書（REQ 編號）、使用情境
│   ├── 02-architecture/         架構、模組邊界、介面規格、本文件
│   ├── 03-design/               模組細部設計、資料模型
│   ├── 04-test/                 測試計畫、測試報告、黃金測試集說明
│   ├── 05-release/              各版本發行說明
│   ├── 06-deployment/           安裝、升級、備份還原、導入檢核表
│   ├── 07-user/                 使用者手冊、教育訓練教材
│   ├── 08-security/             資安、個資、威脅分析、SBOM
│   ├── 09-quality/              開發程序、需求追溯矩陣、審查紀錄
│   ├── adr/                     架構決策紀錄（一個決策一個檔案）
│   └── discussions/             討論紀錄（依日期命名）
│
├── src/                    ⏳   程式碼
│   ├── core/                    知識核心：組織、框架、證據規格、文件、設定繼承
│   ├── modules/                 應用模組（各自獨立，每個都有自己的 README）
│   │   ├── intake/  classify/  completeness/  consistency/  mapping/
│   │   ├── doc_control/  signoff/  change_impact/  pdca/  dashboard/
│   ├── agents/                  Agent 編排層（以授權開關啟用）
│   │   ├── bootstrap/           導入分析
│   │   └── monitor/             稽核監控
│   ├── ai/                      AI 服務層：任務介面、路由、提示詞、呼叫紀錄
│   ├── adapters/                轉接器
│   │   ├── storage/  archive/  intake/  notify/  model/  auth/
│   ├── api/                     對外 API
│   └── web/                     使用介面
│
├── domain_packs/           ⏳   領域套件（內容資產，有獨立的版本）
│   └── healthcare/              醫療：框架結構、文件分類、證據規格範本、單位角色範本
│
├── db/                     ✅   資料庫遷移腳本、示範資料、SQL 測試
├── eval/                   ⏳   AI 黃金測試集（只放去識別化資料或模擬資料）與評測腳本
├── tests/                  ⏳   單元測試／整合測試／端對端測試
├── deploy/                 ✅   容器設定、安裝腳本、環境範本
├── tools/                  ✅   開發輔助腳本
└── .github/                ✅   PR 範本、Issue 範本、CI 工作流程
```

## 規則

- **每個模組資料夾都要有 README**，說明：這個模組做什麼、對外提供哪些介面、依賴哪些模組、對應哪些需求編號。
- 模組之間只能透過公開介面互相呼叫，不可以讀取別的模組的內部資料表。
- 領域套件與程式碼分開：內容資產有自己的版本號與授權問題。
- **不可以進入程式庫的東西**：合約、報價、院方的真實資料、密鑰。`data/`、`private/`、`.env` 已經列在 `.gitignore`。
