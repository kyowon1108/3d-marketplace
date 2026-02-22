# Evidence Report
- Date: 2026-02-22
- Topic: Asset status/availability rules verified
- Gate: B

## 1) Commands Executed
```bash
pytest services/api/tests/ -v -k "asset" --tb=short
```

## 2) Result Summary
### State Machine (5 states)
```
INITIATED → UPLOADING → READY → PUBLISHED
                      ↘ FAILED
```

- `uploads/init` creates asset with status `INITIATED`, transitions to `UPLOADING` after presigned URLs issued.
- `uploads/complete` verifies files and transitions `UPLOADING → READY` (or `UPLOADING → FAILED` on verification failure).
- `products/publish` transitions `READY → PUBLISHED`.
- Invalid transitions (e.g., `INITIATED → READY`, `FAILED → READY`) are rejected.

### Availability Computation
| Asset Status | Has Model File | Availability |
|---|---|---|
| READY | Yes | `READY` |
| PUBLISHED | Yes | `READY` |
| INITIATED | -- | `PROCESSING` |
| UPLOADING | -- | `PROCESSING` |
| FAILED | -- | `NONE` |
| (no asset) | -- | `NONE` |

### Tests Passing
- `test_ar_asset_ready` -- product with READY asset returns availability=READY and file URLs
- `test_model_asset_status` -- GET /v1/model-assets/{assetId} returns correct status at each stage
- `test_ar_asset_none_no_asset` -- product without linked asset returns availability=NONE
- Additional: `test_ar_asset_processing`, `test_ar_asset_none_failed`

## 3) Interpretation
The asset state machine enforces the documented 5-state flow. Availability is derived deterministically from asset status and file presence. No shortcut transitions are possible -- the only path to `READY` is through successful upload verification.

## 4) Decision
**PASS** -- State machine transitions correct, availability mapping verified, tests green.

## 5) Follow-up
- Confirm iOS client respects availability values for CTA enable/disable (Gate C scope).
- Consider adding a periodic reconciliation job for stuck `UPLOADING` assets (operational hardening).
