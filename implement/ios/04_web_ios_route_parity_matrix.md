# iOS-04. Web -> iOS Route Parity Matrix

## Summary
웹 canonical route를 iOS에서 동일 사용자 의미로 매핑한다.

| Web Route | iOS Screen | Required API | Parity Notes |
|---|---|---|---|
| `/` | Home | `GET /v1/products` | 피드형 목록 + 로딩/빈상태 |
| `/products` | Product List | `GET /v1/products` | 필터/정렬/페이징 상태 포함 |
| `/products/[productRef]` | Product Detail | `GET /v1/products/{id}`, `GET /v1/products/{id}/ar-asset`, `POST /v1/products/{id}/chat-rooms` | 인앱 AR 기본 CTA |
| `/search` | Search | `GET /v1/products?q=...` | 최근 검색 + 빈결과 카피 |
| `/app/sell/new` | Sell New | `POST /v1/model-assets/uploads/init`, `POST /v1/model-assets/uploads/complete`, `POST /v1/products/publish` | iOS 로컬 모델링 기준 |
| `/app/reconstructions/[jobId]` | Upload/Publish Status | `GET /v1/model-assets/{assetId}` | 레거시 경로명 유지, 의미는 업로드 상태 |
| `/app/inbox` | Inbox | `GET /v1/chat-rooms` | 빈상태/지연상태 안내 포함 |
| `/app/inbox/[roomId]` | Chat Room | `GET /v1/chat-rooms/{roomId}/messages`, `POST /v1/chat-rooms/{roomId}/messages`, `WS /v1/chats/{roomId}` | WS fallback HTTP |
| `/app/profile` | Profile | `GET /v1/me/summary`, `GET /v1/auth/me` | 통계 카드 상태 포함 |
| `/auth/login` | Login | `GET /v1/auth/providers`, `GET /v1/auth/oauth/dev/callback` | dev-minimal auth |
| `/auth/signup` | Signup | login과 동일 contract 재사용 | dev-minimal auth |

## Parity Definition
1. Pixel perfect 불필요
2. 구조/카피/상태 일치 필수
3. 비즈니스 규칙(asset status/availability) 일치 필수
