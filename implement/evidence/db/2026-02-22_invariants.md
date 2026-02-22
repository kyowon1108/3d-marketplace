# Evidence Report Template

- Date: 2026-02-22
- Topic: Asset status transition, idempotency uniqueness, checksum/size persistence
- Gate: A

## 1) Commands Executed
```bash
pytest services/api/tests/ -v --tb=short
```

## 2) Result Summary
- 27 tests 전체 PASS (0 failures, 0 errors)
- 핵심 검증 항목별 테스트 결과:

### Asset Status Transition
| Test | Result | 검증 내용 |
|---|---|---|
| `test_complete_upload_success` | PASS | INITIATED → UPLOADING → READY 전환 정상 |
| `test_publish_success` | PASS | READY → PUBLISHED 전환 정상 |
| `test_publish_non_ready_asset` | PASS | non-READY 상태에서 publish 시도 → 400 거부 |

### Upload Integrity (checksum/size)
| Test | Result | 검증 내용 |
|---|---|---|
| `test_complete_upload_checksum_mismatch` | PASS | checksum 불일치 → 409 Conflict 반환 |
| `test_complete_upload_missing_object` | PASS | S3 object 미존재 → 409 Conflict 반환 |
| `test_complete_upload_size_mismatch` | PASS | size 불일치 → 409 Conflict 반환 |

### Idempotency
| Test | Result | 검증 내용 |
|---|---|---|
| `test_complete_upload_idempotency_replay` | PASS | 동일 Idempotency-Key로 재요청 → 동일 결과, side effect 없음 |
| `test_publish_idempotency_replay` | PASS | publish 재요청 → 동일 결과, side effect 없음 |

### Checksum/Size Persistence
- `test_complete_upload_success`에서 완료 후 model_asset_files 레코드의 `checksum_sha256`, `size_bytes` 필드가 요청값과 일치함을 검증

## 3) Interpretation
- Asset 상태 머신의 5-state 전환 규칙이 테스트를 통해 검증되었다:
  - 정상 경로: INITIATED → UPLOADING → READY → PUBLISHED
  - 실패 경로: non-READY publish 거부 (400), checksum/size 불일치 (409), missing object (409)
- Idempotency-Key 중복 요청 시 동일 결과 재반환, side effect 없음이 확인되었다.
- checksum(sha256) + size 검증이 upload complete 단계에서 필수적으로 수행됨을 확인했다.
- CLAUDE.md 불변조건 #3(status transition), #6(checksum+size 검증), #7(idempotency) 모두 충족.

## 4) Decision
- `PASS`

## 5) Follow-up
- 테스트에서 TRUNCATE 방식으로 DB 정리 중 — transaction rollback 방식 전환 검토 (성능/격리 개선).
- UPLOADING → FAILED 전환 경로는 현재 timeout/background job에서 처리 예정 — Gate B에서 구현 검증.
