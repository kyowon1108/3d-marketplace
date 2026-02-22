# DB-01. Schema Invariants

## Summary
DB 파트는 `capture/model-asset/publish` 파이프라인 무결성을 복구하는 단계다.

## 1) Required Core Tables
1. `capture_sessions` (optional capture metadata)
2. `model_assets` (iOS가 생성한 모델 메타)
3. `model_asset_files` (usdz/glb/png key, size, checksum)
4. `products` (게시 정보 + asset linkage)
5. `idempotency_keys` (upload complete/publish 재시도 안전성)

## 2) Key Constraints
1. `model_assets`: unique `(id)`
2. `model_asset_files`: unique `(asset_id, file_role)` where file_role in `MODEL_USDZ|MODEL_GLB|PREVIEW_PNG`
3. `model_asset_files`: unique `(storage_key)`
4. `idempotency_keys`: unique `(actor_id, method, path, key)`

## 3) Asset Invariants
1. `model_assets.status` 전이는 `INITIATED -> UPLOADING -> READY -> PUBLISHED` (실패 시 `FAILED`)
2. `READY` 상태는 필수 파일(최소 USDZ 또는 GLB) 검증 완료 상태여야 한다.
3. `products.asset_id`는 `model_assets.status=READY|PUBLISHED`만 참조 가능해야 한다.

## 4) Data Integrity Invariants
1. checksum(sha256)와 size_bytes는 complete 단계에서 저장/검증
2. artifact key는 tenant/owner scope 정책을 따름
3. dims_source는 `ios_lidar|ios_manual|unknown` 중 하나

## 5) Validation SQL
```sql
SHOW INDEX FROM model_asset_files;
SHOW INDEX FROM idempotency_keys;

SELECT id, owner_id, status, dims_source, created_at
FROM model_assets
WHERE id = '<asset_id>';

SELECT asset_id, file_role, storage_key, size_bytes, checksum_sha256
FROM model_asset_files
WHERE asset_id = '<asset_id>'
ORDER BY file_role;
```

## 6) Evidence Expectations
- SQL output snapshot: `evidence/db/YYYY-MM-DD_schema_checks.md`
- invariant summary: `evidence/db/YYYY-MM-DD_invariants.md`
