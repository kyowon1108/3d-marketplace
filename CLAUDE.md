# 3D Marketplace — Claude Code Project Context

## What This Is
iPhone으로 실물 제품을 3D 스캔 → **iOS 로컬 모델링** → AR 체험 구매 플랫폼.
서버는 모델 생성/수정 없음. 순수 ingest/store/publish 역할.

## Monorepo Structure (target)
```
apps/web/          Next.js 14 App Router, TypeScript, Tailwind
apps/ios/          SwiftUI, ARKit, CaptureKit, ModelingKit
services/api/      FastAPI, SQLAlchemy, Alembic, PostgreSQL
docs/api/          openapi.yaml (source of truth)
infra/compose/     Docker Compose
implement/         Gate-based refactor docs (read-only reference)
```

## Source of Truth
- API contract: `docs/api/openapi.yaml`
- API behavior: `services/api/app/routers/*`
- Web types: `apps/web/lib/api.generated.ts` (generated from openapi.yaml)
- iOS contract: `apps/ios/Modules/Networking/ContractEnums.swift`, `APIClient.swift`

## Invariants — NEVER Break
1. `/v1` public API: additive-only, no breaking changes
2. `model_asset_files`: unique `(asset_id, file_role)`, unique `(storage_key)`
3. asset status transition: `INITIATED → UPLOADING → READY → PUBLISHED` (or `FAILED`)
4. `products.asset_id`는 `status=READY|PUBLISHED` asset만 참조 가능
5. publish는 `asset.status=READY` 이후에만 허용
6. upload complete: checksum(sha256) + size 검증 필수
7. Idempotency-Key 중복 요청: 동일 결과 재반환, side effect 없음
8. OpenAPI 변경 시 반드시 TS + Swift generated clients 동기화

## Asset State Machine
`INITIATED → UPLOADING → READY → PUBLISHED`
`UPLOADING → FAILED`

## ar-asset Availability
- `READY`: AR 배치 가능한 모델 파일 존재
- `PROCESSING`: 업로드/검증 중
- `NONE`: 실패 또는 usable asset 없음

## dims.source Values
`ios_lidar | ios_manual | unknown`

## AI Work Rules (from implement/ops/)
**Work loop**: Intake → Plan → Execute → Validate → Document → Commit → Report

### Before starting any task:
- Gate 확인 (A/B/C), 선행 Gate PASS 여부 확인
- `implement/` 관련 checklist 현재 상태 확인
- `EnterPlanMode` 사용 (비자명한 변경은 항상 계획 먼저)

### After completing any task:
- 해당 Gate checklist 항목 `PENDING → PASS/FAIL` 갱신
- `implement/evidence/{db|backend|ios}/YYYY-MM-DD_<topic>.md` 생성
- 출력 보고: 변경 파일, 검증 명령/결과, evidence 경로, 남은 리스크

### Prohibited:
- 승인 없는 스코프 확장
- evidence 없는 Gate 완료 선언
- 체크리스트 미갱신 상태에서 커밋

## Branch & Commit Convention
Branch: `codex/gate{0|a|b|c}-<topic>`
Commit: `<type>(<area>): <intent>`
Types: `feat | fix | refactor | docs | chore`

Examples:
- `feat(db): add model_assets and idempotency_keys tables`
- `fix(backend): enforce checksum validation on upload complete`
- `docs(ios): update seller flow evidence`

## Gate Checklist Files
- Gate A: `implement/db/04_gate_a_checklist.md`
- Gate B: `implement/backend/05_gate_b_checklist.md`
- Gate C: `implement/ios/05_gate_c_checklist.md`

## Evidence Files Location
- DB: `implement/evidence/db/YYYY-MM-DD_<topic>.md`
- Backend: `implement/evidence/backend/YYYY-MM-DD_<topic>.md`
- iOS: `implement/evidence/ios/YYYY-MM-DD_<topic>.md`

## Key Validation Commands
```bash
# DB
alembic -c services/api/alembic.ini upgrade head
alembic -c services/api/alembic.ini current

# Backend
pytest services/api/tests/
ruff check services/api/
mypy services/api/

# Web
cd apps/web && npx tsc --noEmit

# Docker
docker compose -f infra/compose/docker-compose.local.yml up -d
curl -sS http://localhost:8000/healthz
```

## Skills Available
- `/task-brief` — 새 작업 brief 작성
- `/gate-check` — 현재 Gate 체크리스트 상태 요약
- `/evidence` — evidence 파일 생성
- `/pr` — OPS-04 형식 PR 생성
