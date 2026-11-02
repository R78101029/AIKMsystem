#!/usr/bin/env bash
# 在暫存目錄起一個拋棄式 PostgreSQL 16（需已安裝 postgresql-16 與 postgresql-16-pgvector），
# 依序套用 migrations → seed → smoke tests，結束後清除。
# 有 Docker 的話改用：make db-up && make db-test
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
WORK="$(mktemp -d)"
PORT="${PGPORT_TEST:-55432}"
RUN_AS=()
if [ "$(id -u)" = "0" ]; then
  chown postgres "$WORK"; RUN_AS=(runuser -u postgres --)
fi
cleanup() { "${RUN_AS[@]}" "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

"${RUN_AS[@]}" "$PGBIN/initdb" -D "$WORK/data" -U postgres -E UTF8 --locale=C.UTF-8 >/dev/null
"${RUN_AS[@]}" "$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" -l "$WORK/log" start >/dev/null

PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -c "CREATE DATABASE km_test" >/dev/null
for f in "$ROOT"/db/migrations/*.sql "$ROOT"/db/seed/*.sql; do
  echo ">> $(basename "$f")"; "${PSQL[@]}" -d km_test -f "$f"
done
"${PSQL[@]}" -d km_test -f "$ROOT/db/tests/smoke.sql"
