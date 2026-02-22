# BE-01. API Contract & Asset State Machine

## Summary
Backend는 `/v1` 경로 비파괴 유지를 전제로 **모델 업로드/검증/게시/조회** 계약을 복구한다.

## 1) Required Endpoints
### Asset Upload/Publish
1. `POST /v1/model-assets/uploads/init`
2. `POST /v1/model-assets/uploads/complete`
3. `GET /v1/model-assets/{assetId}`
4. `POST /v1/products/publish`
5. `GET /v1/products/{id}/ar-asset`

### Browse/Chat/Auth
6. `GET /v1/products`
7. `GET /v1/products/{id}`
8. `POST /v1/products/{id}/chat-rooms`
9. `GET /v1/chat-rooms`
10. `GET /v1/chat-rooms/{roomId}/messages`
11. `POST /v1/chat-rooms/{roomId}/messages`
12. `WS /v1/chats/{roomId}`
13. `GET /v1/auth/providers`
14. `GET /v1/auth/oauth/{provider}/callback`
15. `GET /v1/auth/me`
16. `GET /v1/me/summary`

## 2) Asset States
1. `INITIATED`
2. `UPLOADING`
3. `READY`
4. `FAILED`
5. `PUBLISHED`

## 3) Status/Availability Rules
1. `model-assets`는 asset 상태를 제공한다.
2. `ar-asset.availability`는 asset/file 준비 상태로 계산한다.
   - `READY`: AR 배치 가능한 모델 파일 존재
   - `PROCESSING`: 업로드/검증 중
   - `NONE`: 실패 또는 usable asset 없음

## 4) Compatibility Rule
1. `/v1` path breaking 금지
2. 필드 변경은 additive optional 우선
3. OpenAPI 변경 시 generated clients 동기화 필수

## 5) Evidence Expectations
- contract tests: `evidence/backend/YYYY-MM-DD_contract_tests.md`
- sample payloads: `evidence/backend/YYYY-MM-DD_payload_samples.md`
