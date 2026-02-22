# BE-02. Upload Idempotency & Security

## Summary
이 아키텍처는 callback이 아니라 **upload complete/publish idempotency + 파일 무결성 검증**이 핵심이다.

## 1) Required Security Checks
1. 인증 사용자만 upload init/complete/publish 가능
2. presigned URL 만료 시간 강제
3. complete 시 object existence/size/checksum 검증
4. owner scope로 asset 접근 제한

## 2) Idempotency Contract
1. `Idempotency-Key` 헤더 지원 (complete/publish)
2. duplicate key는 동일 결과 재반환(no duplicate side effect)
3. state mutation은 idempotency 확인 이후에만 수행

## 3) Retry Model
1. 모바일 네트워크 재시도 허용
2. complete/publish 재요청은 idempotent 해야 함

## 4) Failure Modes
1. checksum mismatch -> 409
2. missing object -> 409
3. owner mismatch -> 403
4. duplicate idempotency key (payload hash mismatch) -> 409

## 5) Evidence Expectations
- upload integrity logs: `evidence/backend/YYYY-MM-DD_upload_integrity.md`
- idempotency replay evidence: `evidence/backend/YYYY-MM-DD_idempotency.md`
