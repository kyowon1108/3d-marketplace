# Evidence Report
- Date: 2026-02-22
- Topic: Idempotency replay no-op works
- Gate: B

## 1) Commands Executed
```bash
pytest services/api/tests/ -v -k "idempotency" --tb=short
```

## 2) Result Summary
### Idempotency-Key Behavior

The `Idempotency-Key` header is required on mutating endpoints that must be safe to retry:
- `POST /v1/model-assets/uploads/complete`
- `POST /v1/products/publish`

#### Scenarios

| Scenario | Behavior | HTTP Status |
|---|---|---|
| First request with key | Processes normally, caches response in `idempotency_keys` table | 200 |
| Duplicate key + identical body | Returns cached response, **no side effects** | 200 (cached) |
| Duplicate key + different body | Rejects as conflict | 409 Conflict |
| Missing Idempotency-Key header | Rejects request | 400 Bad Request |

#### Storage
- `idempotency_keys` table with unique constraint on `(actor_id, method, path, key)`.
- Cached response includes status code and JSON body.
- TTL-based cleanup is a future operational concern (not blocking Gate B).

### Tests Passing
| Test | Validates |
|---|---|
| `test_complete_upload_idempotency_replay` | Duplicate uploads/complete returns cached 200, asset not re-processed |
| `test_publish_idempotency_replay` | Duplicate publish returns cached 200, product not re-created |
| `test_complete_upload_no_idempotency_key` | Missing header returns 400 |
| `test_idempotency_key_body_mismatch` | Same key + different body returns 409 |

## 3) Interpretation
Idempotency handling satisfies Invariant #7: duplicate requests with the same key return identical results with zero side effects. The implementation uses a database-backed cache keyed by actor + method + path + key, ensuring correctness even across server restarts. Body fingerprinting (hash comparison) detects misuse of keys across different payloads.

## 4) Decision
**PASS** -- Idempotency replay, conflict detection, and missing-key rejection all verified.

## 5) Follow-up
- Implement TTL-based cleanup of expired idempotency keys (operational hardening).
- Monitor idempotency_keys table growth in production.
