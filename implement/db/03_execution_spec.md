# DB-03. Execution Spec

## Entry Criteria
1. Gate 0 완료
2. baseline env file 생성됨
3. alembic config and model scaffolds 존재

## Work Breakdown
### A. Schema Build
1. core model files 생성 (`capture/model_asset/product/idempotency`)
2. alembic env and revision chain 구성
3. migration 순서대로 작성/적용

### B. Invariant Hardening
1. asset status transition 보장
2. upload complete/publish idempotency 보강
3. storage key/checksum uniqueness 보장

### C. Verification
1. migration head 검증
2. key constraint/index 검증
3. sample asset row 검증

## Deliverables
1. DB schema + migrations
2. SQL check outputs
3. Gate A checklist 업데이트

## Exit Criteria
1. `db/04_gate_a_checklist.md` 전 항목 PASS
2. `evidence/db/*` 증빙 파일 생성
