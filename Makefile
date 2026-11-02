-include .env
export

COMPOSE = docker compose -f deploy/docker-compose.dev.yml --env-file .env
PSQL = $(COMPOSE) exec -T db psql -v ON_ERROR_STOP=1 -U $${POSTGRES_USER:-km} -d $${POSTGRES_DB:-km}

.PHONY: db-up db-down db-migrate db-seed db-test db-reset db-test-local

db-up:
	$(COMPOSE) up -d --wait db

db-down:
	$(COMPOSE) down

db-migrate:
	@for f in db/migrations/*.sql; do echo ">> $$f"; $(PSQL) -f /$$f || exit 1; done

db-seed:
	@for f in db/seed/*.sql; do echo ">> $$f"; $(PSQL) -f /$$f || exit 1; done

db-test:
	$(PSQL) -f /db/tests/smoke.sql

db-reset:
	$(COMPOSE) down -v
	$(MAKE) db-up db-migrate

# 不用 Docker：本機 PostgreSQL 16 + pgvector，拋棄式資料庫
db-test-local:
	./tools/db-test-local.sh
