# 部署文件（從第一天維護）

| 項目 | 內容 |
|---|---|
| 版次 | 0.1 |
| 日期 | 2026-11-03 |

> 目標：任何接手的工程師或合作資訊公司，只看這份文件就能把系統架起來。每次架構變動都要同步更新。

## 目前狀態（v0.1）
只有資料庫層。應用程式尚未建立。

## 需求
- PostgreSQL 16 + pgvector 0.6 以上
- （開發）Docker 與 Docker Compose，或本機安裝 `postgresql-16` 與 `postgresql-16-pgvector`

## 開發環境

使用 Docker：

```bash
cp .env.example .env
```

```bash
make db-up
```

```bash
make db-migrate
```

```bash
make db-seed
```

```bash
make db-test
```

（seed 只能套用一次；要重來用 `make db-reset`。）

不使用 Docker（本機已安裝 PostgreSQL 16 與 pgvector，會起一個拋棄式資料庫跑完全部測試）：

```bash
./tools/db-test-local.sh
```

## 資料庫遷移規則
- 檔案放 `db/migrations/`，以四位數字遞增命名：`0002_xxx.sql`
- 已合併到主線的 migration **不得修改**，只能新增
- 每個 migration 包在 `BEGIN; … COMMIT;` 內
- `db/seed/` 只放虛構示範資料，不得含真實院內資料或受著作權保護的條文

## 正式部署（預計，MVP-1 前補齊）
- 部署型態：院內地端 VM／容器
- 備份：每日 `pg_dump` + WAL 歸檔；定期還原演練
- 密鑰：透過環境變數或密鑰管理，資料庫只存 `secret_ref`
- 模型服務：地端推論伺服器，經模型閘道存取
- 監控：資料庫、模型延遲、同步失敗、通知失敗
