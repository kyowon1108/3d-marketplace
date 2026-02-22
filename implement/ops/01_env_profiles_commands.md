# OPS-01. Environment Profiles & Commands

## Summary
빈 저장소에서 복구할 때는 환경 프로파일을 먼저 고정해야 drift를 막을 수 있다.

핵심:
- iOS가 모델링을 수행하므로 서버 GPU 추론 모드는 필요 없다.

## 1) Local Profile
- `APP_ENV=local`
- `MODEL_PIPELINE_MODE=ios_local`
- `NEXT_PUBLIC_MVP_APP_ONLY=false`

### Bootstrap Commands
```bash
make setup
cp .env.example .env
docker compose -f infra/compose/docker-compose.local.yml up -d
```

## 2) Server Profile
- `APP_ENV=prod`
- `MODEL_PIPELINE_MODE=ios_local`
- `AUTH_COOKIE_SECURE=true`
- `OAUTH_ALLOW_DEV_PROVIDER=false`
- `NEXT_PUBLIC_MVP_APP_ONLY=true`

### Bring-up Commands
```bash
docker compose -f infra/compose/docker-compose.core.yml up -d --build
docker compose -f infra/compose/docker-compose.web.yml up -d --build
```

## 3) Health Commands
```bash
curl -sS http://<api-host>:8000/healthz
curl -sS http://<api-host>:8000/readyz
curl -sS http://<api-host>:8000/healthz/dependencies
```

## 4) Evidence Expectations
- env snapshot: `evidence/backend/YYYY-MM-DD_env_snapshot.md`
- health checks: `evidence/backend/YYYY-MM-DD_health_checks.md`
