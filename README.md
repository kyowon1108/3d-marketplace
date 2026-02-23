# 3D Marketplace

iPhone으로 실물 제품을 3D 스캔하고, iOS 로컬 모델링을 거쳐, AR 체험 후 구매할 수 있는 C2C 마켓플레이스 플랫폼.

서버는 모델 생성/수정 연산 없이, 순수 ingest/store/publish 역할만 담당한다.

---

## Monorepo 구조

```
apps/web/          Next.js 14 App Router, TypeScript, Tailwind
apps/ios/          SwiftUI, ARKit, CaptureKit, ModelingKit
services/api/      FastAPI, SQLAlchemy, Alembic, PostgreSQL
docs/api/          openapi.yaml (API contract source of truth)
infra/compose/     Docker Compose (local / beta)
implement/         Gate-based refactor docs + evidence
```

---

## 핵심 플로우

**Seller (iOS)**:
Sweep Capture → Frame Selection → Local Model Build → USDZ Export → Presigned Upload → Complete Verify → Publish

**Buyer (iOS/Web)**:
Product Browse → Product Detail → AR Placement (footprint-first, 단일 모델) → 채팅 / 구매

---

## Database

PostgreSQL 16. Alembic으로 마이그레이션 관리 (현재 revision 011).

### 테이블 목록

| Table | 설명 |
|-------|------|
| `users` | 사용자. email, name, provider, location_name |
| `products` | 게시 상품. title, price, status (FOR_SALE/RESERVED/SOLD_OUT), seller/asset 연결 |
| `purchases` | 구매 내역. product_id, buyer_id, price_cents. unique(product_id) |
| `model_assets` | iOS가 생성한 3D 모델 메타. status: INITIATED → UPLOADING → READY → PUBLISHED (or FAILED) |
| `model_asset_files` | 모델 파일 (MODEL_USDZ, MODEL_GLB, PREVIEW_PNG). checksum, size 검증 |
| `asset_images` | 상품 이미지 (THUMBNAIL, DISPLAY). sort_order 지원 |
| `capture_sessions` | iOS sweep capture 세션 메타데이터 |
| `chat_rooms` | 1:1 채팅방. product 기준, buyer+seller. last_message_body, unread 추적 |
| `chat_messages` | 채팅 메시지. room_id, sender_id, body |
| `product_likes` | 상품 좋아요. user+product unique |
| `idempotency_keys` | upload complete/publish 멱등성 보장 |
| `refresh_tokens` | JWT refresh token 저장 및 revocation |

### Asset 상태 머신

```
INITIATED → UPLOADING → READY → PUBLISHED
                      ↘ FAILED
```

### 주요 제약조건

- `model_asset_files`: unique (asset_id, file_role), unique (storage_key)
- `products.asset_id`는 status=READY 또는 PUBLISHED인 asset만 참조 가능
- `purchases.product_id`: unique (1회 구매)
- publish는 asset.status=READY 이후에만 허용
- upload complete 시 checksum(sha256) + size 검증 필수

---

## API

FastAPI 기반. OpenAPI 스펙은 `docs/api/openapi.yaml`에 정의.

### 엔드포인트 목록 (18개)

#### Auth

| Method | Path | 설명 |
|--------|------|------|
| GET | `/v1/auth/providers` | 사용 가능한 인증 프로바이더 목록 |
| GET | `/v1/auth/oauth/{provider}/callback` | OAuth 콜백 (dev: code=email:name) |
| POST | `/v1/auth/oauth/{provider}/token` | 모바일 토큰 교환 (iOS → Google id_token) |
| POST | `/v1/auth/token/refresh` | Access token 갱신 |
| POST | `/v1/auth/logout` | Refresh token 폐기 |
| GET | `/v1/auth/me` | 현재 사용자 정보 |
| GET | `/v1/me/summary` | 사용자 요약 (상품 수, 구매 수, 안 읽은 메시지) |

#### Upload / Asset

| Method | Path | 설명 |
|--------|------|------|
| POST | `/v1/model-assets/uploads/init` | Presigned upload URL 발급 |
| POST | `/v1/model-assets/uploads/complete` | 파일 검증 후 READY 전환 (Idempotency-Key 필수) |
| GET | `/v1/model-assets/{assetId}` | Asset 상태 조회 |

#### Products

| Method | Path | 설명 |
|--------|------|------|
| POST | `/v1/products/publish` | READY asset을 상품으로 게시 (Idempotency-Key 필수) |
| GET | `/v1/products` | 상품 목록 (검색, 페이징, seller/liked 필터) |
| GET | `/v1/products/{id}` | 상품 상세 (조회수 자동 증가) |
| POST | `/v1/products/{id}/like` | 좋아요 토글 |
| GET | `/v1/products/{id}/ar-asset` | AR asset 조회 (availability: READY/PROCESSING/NONE) |
| POST | `/v1/products/{id}/purchase` | 상품 구매 (자기 상품 불가, 중복 구매 409) |
| POST | `/v1/products/{id}/chat-rooms` | 상품 채팅방 생성 |

#### Chat

| Method | Path | 설명 |
|--------|------|------|
| GET | `/v1/chat-rooms` | 내 채팅방 목록 |
| POST | `/v1/chat-rooms/{roomId}/read` | 읽음 처리 |
| GET | `/v1/chat-rooms/{roomId}/messages` | 메시지 조회 (cursor pagination) |
| POST | `/v1/chat-rooms/{roomId}/messages` | 메시지 전송 |
| WS | `/v1/chats/{roomId}?token=` | 실시간 채팅 (WebSocket) |

### 인증

- JWT access token (30분) + refresh token (30일) 방식
- `Authorization: Bearer <token>` 헤더
- Local/test 환경에서는 dev auth (email:name code) 지원
- Google OAuth (id_token 검증 또는 auth code 교환) — 베타 준비 중

### 보안

- beta/production 환경: `jwt_secret_key` 32자 이상 강제, dev auth 비활성화
- upload complete: SHA256 checksum + size 검증
- Idempotency-Key: 중복 요청 시 동일 결과 재반환, side effect 없음
- local storage: presigned URL 서명 검증 (HMAC-SHA256)

---

## iOS

SwiftUI 기반. 11개 화면으로 웹 라우트와 1:1 대응.

### 화면 구성

| Web Route | iOS Screen | 주요 API |
|-----------|------------|----------|
| `/` | Home | GET /v1/products |
| `/products` | ProductList | GET /v1/products (카테고리 필터: 최신순/인기순/무료) |
| `/products/[id]` | ProductDetail | GET /v1/products/{id}, ar-asset, chat-rooms, purchase |
| `/search` | Search | GET /v1/products?q= |
| `/app/sell/new` | SellNew | uploads/init, uploads/complete, products/publish |
| `/app/reconstructions/[jobId]` | UploadStatus | GET /v1/model-assets/{assetId} |
| `/app/inbox` | Inbox | GET /v1/chat-rooms |
| `/app/inbox/[roomId]` | ChatRoom | messages + WebSocket |
| `/app/profile` | Profile | me/summary, auth/me, 내 상품/구매 내역 |
| `/auth/login` | Auth (Login) | auth/providers, oauth callback |
| `/auth/signup` | Auth (Signup) | auth/providers, oauth callback |

### 모듈 구조

```
apps/ios/
├── App/                  앱 진입점 (MarketplaceApp, ContentView, AppEnvironment)
├── DesignSystem/          공용 컴포넌트, Theme, Modifiers
├── Features/              화면별 View + ViewModel
│   ├── Auth/
│   ├── Home/
│   ├── Inbox/
│   ├── ChatRoom/
│   ├── ProductDetail/
│   ├── ProductList/
│   ├── Profile/
│   ├── Search/
│   ├── SellNew/
│   └── UploadStatus/
├── Modules/
│   ├── ARPlacementKit/    AR 배치 (footprint-first, plane detection)
│   ├── Auth/              AuthManager, KeychainHelper
│   ├── CaptureKit/        SweepCaptureEngine, FrameSelector
│   ├── ModelingKit/       LocalModelBuilder, ModelExportCoordinator
│   └── Networking/        APIClient, WebSocketManager, APIContracts
└── Resources/             Assets, 설정 파일
```

### Seller 플로우

1. SweepCaptureEngine으로 10~20초 스캔 (LiDAR 필수)
2. FrameSelector로 품질/yaw 기반 프레임 선택
3. LocalModelBuilder로 로컬 3D 모델 생성 (PhotogrammetrySession)
4. USDZ export + 썸네일 자동 생성 (QLThumbnailGenerator → SceneKit fallback)
5. uploads/init → presigned upload → uploads/complete (SHA256 checksum 검증)
6. products/publish (asset.status=READY 이후에만 가능)

### Buyer 플로우

1. 상품 목록/검색 → 상세 진입
2. ar-asset 조회 → availability=READY 확인 → USDZ 다운로드
3. Footprint-first AR 배치 (RealityKit) 또는 Quick Look fallback
4. dims.source=ios_lidar → "LiDAR 정밀 스캔 인증됨" / 기타 → "수동 측정 (오차 가능)"
5. 채팅 또는 구매 → 구매 시 SOLD_OUT 상태 즉시 반영

---

## 로컬 개발

### 요구사항

- Docker, Docker Compose
- Python 3.12+ (uv 권장)
- Node.js 18+
- Xcode 15+ (iOS)

### 실행

```bash
# 인프라 (PostgreSQL, Redis, API, Web)
docker compose -f infra/compose/docker-compose.local.yml up -d

# Health check
curl http://localhost:8000/healthz

# 마이그레이션
cd services/api
alembic -c alembic.ini upgrade head

# 테스트 (TEST_DATABASE_URL 필수)
TEST_DATABASE_URL=postgresql://marketplace:marketplace@localhost:5433/marketplace_test \
  uv run pytest tests/ -v

# Lint
uv run ruff check .
```

### 포트

| Service | Port |
|---------|------|
| API | 8000 |
| Web | 3000 |
| PostgreSQL | 5433 |
| Redis | 6379 |

### iOS 실기기 연결

`apps/ios/App/AppEnvironment.swift`의 `apiBaseURL`/`wsBaseURL`이 로컬 개발 머신의 네트워크 IP를 가리켜야 합니다. 시뮬레이터는 `localhost` 사용 가능하지만 실기기는 불가.

---

## Gate 체계

개발 진행은 Gate 단위로 관리. 각 Gate는 체크리스트 전 항목 PASS + evidence 파일 존재 시 GO.

| Gate | 영역 | 상태 | 체크리스트 |
|------|------|------|-----------|
| A | DB | PASS | `implement/db/04_gate_a_checklist.md` |
| B | Backend | PASS | `implement/backend/05_gate_b_checklist.md` |
| C | iOS | PASS | `implement/ios/05_gate_c_checklist.md` |

Evidence 파일: `implement/evidence/{db,backend,ios}/YYYY-MM-DD_<topic>.md`
