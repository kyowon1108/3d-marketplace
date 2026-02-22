# Evidence Report
- Date: 2026-02-22
- Topic: Upload integrity verification works
- Gate: B

## 1) Commands Executed
```bash
pytest services/api/tests/ -v -k "complete_upload" --tb=short
```

## 2) Result Summary
### Verification Logic (uploads/complete handler)
On `POST /v1/model-assets/uploads/complete`, the backend performs for each declared file:

1. **Object existence check** -- confirms the file exists at the expected storage key (`assets/{assetId}/model.usdz`, `.glb`, `preview.png`).
2. **Size verification** -- compares declared `size_bytes` against actual stored object size.
3. **Checksum verification** -- computes SHA-256 of the stored object and compares against the declared `checksum_sha256`.

If any check fails, the asset transitions to `FAILED` and the endpoint returns `409 Conflict` with a descriptive error.

### Storage Backend
- Development: local file-based storage (`services/api/app/storage/local.py`) implementing the same interface as the S3 adapter.
- Production: S3-compatible storage with presigned URL generation.
- Both backends support `head_object` (existence + size) and `get_object` (for checksum computation).

### Tests Passing
| Test | Scenario | Expected |
|---|---|---|
| `test_complete_upload_success` | Valid files, matching checksum + size | 200, status=READY |
| `test_complete_upload_checksum_mismatch` | SHA-256 does not match | 409 Conflict, status=FAILED |
| `test_complete_upload_missing_object` | File not found at storage key | 409 Conflict, status=FAILED |
| `test_complete_upload_size_mismatch` | Declared size != actual size | 409 Conflict, status=FAILED |

## 3) Interpretation
Upload integrity is enforced server-side regardless of what the client reports. The checksum is computed from the actual stored bytes, not trusted from the client. This prevents corrupted or tampered uploads from reaching `READY` status. Invariant #6 (checksum + size verification) is satisfied.

## 4) Decision
**PASS** -- Checksum (SHA-256) and size verification enforced on every uploads/complete call, failure paths tested.

## 5) Follow-up
- Validate presigned URL expiry enforcement in production S3 configuration.
- Consider adding content-type validation for uploaded model files (USDZ magic bytes, GLB header).
