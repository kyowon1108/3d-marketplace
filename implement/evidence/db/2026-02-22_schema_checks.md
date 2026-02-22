# Evidence Report Template

- Date: 2026-02-22
- Topic: model_asset_files constraints and indexes verified
- Gate: A

## 1) Commands Executed
```sql
-- Constraints 확인
SELECT conname, contype, conrelid::regclass
FROM pg_constraint
WHERE conrelid IN (
  'model_asset_files'::regclass,
  'model_assets'::regclass,
  'idempotency_keys'::regclass,
  'products'::regclass
)
ORDER BY conrelid::regclass::text, conname;

-- Indexes 확인
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

## 2) Result Summary
- **model_asset_files constraints**:
  - `uq_asset_file_role` — UNIQUE(asset_id, file_role): 동일 asset에 같은 role 파일 중복 방지
  - `uq_storage_key` — UNIQUE(storage_key): storage key 전역 유일성 보장
  - `fk_model_asset_files_asset_id` — FK → model_assets(id)
- **model_asset_files indexes**:
  - `ix_model_asset_files_asset_id` — asset_id 조회 최적화
- **model_assets indexes**:
  - `ix_model_assets_owner_status` — owner_id + status 복합 인덱스
- **idempotency_keys constraints**:
  - `uq_idempotency` — UNIQUE(actor_id, method, path, key): 멱등성 키 유일성
- **products indexes**:
  - `ix_products_published_at` — published_at 정렬 조회 최적화
  - `fk_products_asset_id` — FK → model_assets(id)
- 전체 21개 인덱스 확인 (PK 인덱스 포함)

## 3) Interpretation
- CLAUDE.md에 명시된 3개 핵심 불변조건이 DB 수준에서 강제된다:
  1. `model_asset_files`: unique `(asset_id, file_role)` — `uq_asset_file_role`로 충족
  2. `model_asset_files`: unique `(storage_key)` — `uq_storage_key`로 충족
  3. `idempotency_keys`: unique `(actor_id, method, path, key)` — `uq_idempotency`로 충족
- 조회 성능을 위한 인덱스가 적절히 배치되어 있다.
- FK 제약조건으로 orphan record 방지가 보장된다.

## 4) Decision
- `PASS`

## 5) Follow-up
- Production 데이터 볼륨에서의 인덱스 성능은 Gate B 이후 부하 테스트에서 검증 예정.
- `products.asset_id`가 READY|PUBLISHED 상태의 asset만 참조하는 규칙은 DB CHECK 또는 application-level에서 강제 — Gate B에서 검증.
