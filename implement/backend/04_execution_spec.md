# BE-04. Execution Spec

## Entry Criteria
1. Gate A PASS
2. DB head aligned
3. OpenAPI base skeleton exists

## Work Breakdown
### A. Contract Recovery
1. `docs/api/openapi.yaml` 작성/복구
2. required `/v1` endpoints 구현 (upload/publish 중심)
3. additive-only compatibility 검증

### B. Asset State Recovery
1. asset state mapping 구현
2. `ar-asset.availability` 계산 로직 단일화
3. publish precondition (`asset.status=READY`) 보장

### C. Security + Idempotency
1. upload complete integrity 검증 구현
2. idempotency key table/flow 구현
3. duplicate request no-op 경로 테스트

### D. Type Sync
1. web generated type sync
2. iOS contract enum/DTO sync

## Deliverables
1. routers/services/repositories functional path
2. OpenAPI + generated type sync report
3. Gate B checklist update

## Exit Criteria
1. `backend/05_gate_b_checklist.md` all PASS
2. backend evidence files complete
