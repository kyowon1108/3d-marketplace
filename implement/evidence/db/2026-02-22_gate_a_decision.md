# Gate Decision Template

- Gate: `A`
- Date: 2026-02-22
- Decision: `GO`

## 1) Basis
1. Migration chain (001-005) 전체 적용 완료, Alembic current = head 일치 확인
2. model_asset_files의 unique(asset_id, file_role), unique(storage_key) 제약조건 DB 수준 검증 완료
3. idempotency_keys의 unique(actor_id, method, path, key) 제약조건 DB 수준 검증 완료
4. Asset status transition (INITIATED→UPLOADING→READY→PUBLISHED) 테스트 27건 전체 PASS
5. checksum(sha256) + size 검증 로직 테스트 PASS (불일치 시 409 반환)
6. Idempotency-Key 중복 요청 시 동일 결과 재반환 테스트 PASS
7. Rollforward 전략 문서화 완료, emergency downgrade 경로 확인

## 2) Evidence Links
1. `implement/evidence/db/2026-02-22_migration_apply.md` — migration chain + alembic head/current 일치
2. `implement/evidence/db/2026-02-22_schema_checks.md` — constraints, indexes 검증 (21개 인덱스)
3. `implement/evidence/db/2026-02-22_invariants.md` — status transition, idempotency, checksum/size (27 tests PASS)
4. `implement/evidence/db/2026-02-22_rollforward_strategy.md` — rollback/rollforward 전략

## 3) Residual Risks
1. 테스트 suite에서 TRUNCATE 방식으로 DB 정리 — transaction rollback 방식 대비 격리 수준이 낮음 (병렬 테스트 시 간섭 가능성)
2. Production 환경에서의 migration 적용은 별도 검증되지 않음 (local/test DB 기준)
3. UPLOADING → FAILED 전환은 timeout/background job 의존 — Gate B에서 구현 예정
4. `products.asset_id`가 READY|PUBLISHED 상태만 참조하는 규칙은 application-level 강제 — DB CHECK 미적용

## 4) Rollback / Recovery Plan
1. Forward-fix 우선: 문제 발생 시 새 migration으로 수정
2. Emergency: `alembic downgrade <revision>` 으로 계단식 롤백 (데이터 손실 주의)
3. 전체 초기화 필요 시: `alembic downgrade base` + `alembic upgrade head`

## 5) Next Action
1. Gate B (Backend API) 진입 — OpenAPI contract, asset state machine router, upload integrity/idempotency 구현 검증
2. Gate B 시작 전 `implement/backend/05_gate_b_checklist.md` 상태 확인 및 task brief 작성
