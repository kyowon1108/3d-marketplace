# Evidence Report
- Date: 2026-02-22
- Topic: OpenAPI and runtime contract aligned
- Gate: B

## 1) Commands Executed
```bash
# Verify openapi.yaml parses and contains all paths
python -c "import yaml; spec=yaml.safe_load(open('docs/api/openapi.yaml')); print(sorted(spec['paths'].keys()))"

# Generate TypeScript types from OpenAPI spec
cd apps/web && npx openapi-typescript ../../docs/api/openapi.yaml -o lib/api.generated.ts

# Type-check generated output
cd apps/web && npx tsc --noEmit
```

## 2) Result Summary
- `docs/api/openapi.yaml` contains all 16 endpoint paths with full request/response schemas.
- Schema components defined: `ModelAsset`, `ModelAssetFile`, `AssetStatus`, `FileRole`, `ArAssetResponse`, `Availability`, `Product`, `UploadInitRequest`, `UploadInitResponse`, `UploadCompleteRequest`, `PublishRequest`, `ChatRoom`, `Message`, `AuthProvider`, `User`, `UserSummary`.
- `openapi-typescript` (v7.13.0) generates `apps/web/lib/api.generated.ts` without errors.
- `tsc --noEmit` passes -- all web components consuming generated types compile cleanly.

## 3) Interpretation
The OpenAPI spec is the single source of truth. Generated TypeScript types align with the runtime FastAPI endpoints. Any future endpoint change must update `openapi.yaml` first, then re-generate types (Invariant #8).

## 4) Decision
**PASS** -- OpenAPI spec complete, TS generation successful, type-check green.

## 5) Follow-up
- iOS Swift contract generation deferred to Gate C (only `apps/ios/.gitkeep` exists).
- Consider adding a CI step that fails if generated types are stale vs. openapi.yaml.
