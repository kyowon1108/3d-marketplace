.PHONY: setup db-migrate api-dev web-dev test-api lint-api docker-up docker-down

setup:
	cp -n .env.example .env || true
	cd apps/web && npm install
	cd services/api && pip install -r requirements.txt

db-migrate:
	alembic -c services/api/alembic.ini upgrade head

api-dev:
	cd services/api && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

web-dev:
	cd apps/web && npm run dev

test-api:
	pytest services/api/tests/ -v

lint-api:
	ruff check services/api/
	mypy services/api/app/

docker-up:
	docker compose -f infra/compose/docker-compose.local.yml up -d

docker-down:
	docker compose -f infra/compose/docker-compose.local.yml down
