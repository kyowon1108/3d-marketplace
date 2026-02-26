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

## 주요 기능

### 킬러 피처
- **3D 스캔 → AR 체험**: iPhone LiDAR로 실물 스캔, 구매자가 AR로 실제 공간에 배치
- **치수 자동 측정**: LiDAR 기반 가로×세로×높이 자동 추출, 상세 페이지 및 AR 라벨 표시
- **AI 상품 추천**: OpenAI 기반 제목/설명/카테고리/가격 자동 제안 (3D 모델 분석)

### 거래 기능
- **상품 관리**: 등록/수정/삭제(soft delete)/상태 변경(판매중↔예약중↔판매완료)
- **실시간 채팅**: WebSocket 기반 1:1 채팅 + 안전거래 경고 메시지
- **구매/좋아요**: 즉시 구매(SOLD_OUT 자동 전환), 좋아요 토글
- **프로필 관리**: 닉네임/지역 수정, 설정 화면, 로그아웃

### UX 디테일
- **3D Opt-in 로딩**: 상세 진입 시 썸네일 먼저 표시, "3D로 돌려보기" 버튼으로 수동 다운로드
- **셀러 신뢰 지표**: 가입일/거래횟수 표시, 지역 아이콘
- **상태 배지**: 예약중(초록)/판매완료(회색) 캡슐 배지, SOLD_OUT 투명도 처리
- **Pull to Refresh**: 상세 페이지 당겨서 새로고침

---

## Database

PostgreSQL 16. Alembic으로 마이그레이션 관리 (현재 revision 014).

### 테이블 목록

| Table | 설명 |
|-------|------|
| `users` | 사용자. email, name, provider, location_name |
| `products` | 게시 상품. title, price, status, category, condition, dims_comparison, seller/asset 연결, deleted_at (soft delete) |
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
- `products.deleted_at`: soft delete (NULL이면 활성, 비NULL이면 삭제됨)
- `purchases.product_id`: unique (1회 구매)
- publish는 asset.status=READY 이후에만 허용
- upload complete 시 checksum(sha256) + size 검증 필수
- `products.category`: CHECK IN (ELECTRONICS, FURNITURE, CLOTHING, BOOKS_MEDIA, SPORTS, LIVING, BEAUTY, HOBBY, OTHER) OR NULL
- `products.condition`: CHECK IN (NEW, LIKE_NEW, USED, WORN) OR NULL
- `ix_products_category_published_at` 복합 인덱스

---

## API

FastAPI 기반. OpenAPI 스펙은 `docs/api/openapi.yaml`에 정의.

### 엔드포인트 목록 (28개)

#### Auth (9개)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/v1/auth/providers` | 사용 가능한 인증 프로바이더 목록 |
| GET | `/v1/auth/oauth/{provider}/callback` | OAuth 콜백 (dev: code=email:name) |
| POST | `/v1/auth/oauth/{provider}/token` | 모바일 토큰 교환 (iOS → Google id_token) |
| POST | `/v1/auth/token/refresh` | Access token 갱신 |
| POST | `/v1/auth/logout` | Refresh token 폐기 |
| GET | `/v1/auth/me` | 현재 사용자 정보 |
| PATCH | `/v1/auth/me` | 프로필 수정 (닉네임, 지역) |
| GET | `/v1/me/summary` | 사용자 요약 (상품 수, 구매 수, 안 읽은 메시지) |
| GET | `/v1/me/purchases` | 구매 내역 목록 |

#### Upload / Asset (3개)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/v1/model-assets/uploads/init` | Presigned upload URL 발급 |
| POST | `/v1/model-assets/uploads/complete` | 파일 검증 후 READY 전환 (Idempotency-Key 필수) |
| GET | `/v1/model-assets/{assetId}` | Asset 상태 조회 |

#### AI (1개)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/v1/ai/suggest-listing` | AI 기반 상품 정보 추천 (제목/설명/카테고리/상태/가격범위/치수비교/가격사유) |

#### Products (10개)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/v1/products/publish` | READY asset을 상품으로 게시 (Idempotency-Key 필수) |
| GET | `/v1/products` | 상품 목록 (검색, 페이징, seller/liked/category 필터) |
| GET | `/v1/products/{id}` | 상품 상세 (조회수 자동 증가, 셀러 가입일/거래횟수 포함) |
| PATCH | `/v1/products/{id}` | 상품 수정 (제목/가격/설명, 소유자만, SOLD_OUT 수정 불가) |
| DELETE | `/v1/products/{id}` | 상품 삭제 (soft delete, 소유자만) |
| PATCH | `/v1/products/{id}/status` | 상태 변경 (FOR_SALE↔RESERVED↔SOLD_OUT, 소유자만) |
| POST | `/v1/products/{id}/like` | 좋아요 토글 |
| GET | `/v1/products/{id}/ar-asset` | AR asset 조회 (availability: READY/PROCESSING/NONE, 치수 포함) |
| POST | `/v1/products/{id}/purchase` | 상품 구매 (자기 상품 불가, 중복 구매 409) |
| POST | `/v1/products/{id}/chat-rooms` | 상품 채팅방 생성 |

#### Chat (5개)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/v1/chat-rooms` | 내 채팅방 목록 |
| POST | `/v1/chat-rooms/{roomId}/read` | 읽음 처리 |
| GET | `/v1/chat-rooms/{roomId}/messages` | 메시지 조회 (cursor pagination) |
| POST | `/v1/chat-rooms/{roomId}/messages` | 메시지 전송 (REST fallback) |
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
- 상품 수정/삭제/상태변경: 소유자 검증 필수

---

## iOS

SwiftUI 기반. 11개 화면으로 웹 라우트와 1:1 대응. 로그인 필수 구조.

### 화면 구성

| Web Route | iOS Screen | 주요 API |
|-----------|------------|----------|
| `/` | Home | GET /v1/products |
| `/products` | ProductList | GET /v1/products(?category=) (정렬: 최신순/인기순/무료, 카테고리 서버 필터) |
| `/products/[id]` | ProductDetail | GET /v1/products/{id}, ar-asset, like, purchase, chat-rooms |
| `/search` | Search | GET /v1/products?q=&category= |
| `/app/sell/new` | SellNew | ai/suggest (8필드), uploads/init, uploads/complete, products/publish |
| `/app/reconstructions/[jobId]` | UploadStatus | GET /v1/model-assets/{assetId} |
| `/app/inbox` | Inbox | GET /v1/chat-rooms |
| `/app/inbox/[roomId]` | ChatRoom | messages + WebSocket |
| `/app/profile` | Profile | me/summary, 내 상품/구매/관심 내역 |
| `/app/profile/edit` | ProfileEdit | PATCH /v1/auth/me |
| `/app/settings` | Settings | 프로필 수정 링크, 앱 버전, 로그아웃 |

### 모듈 구조

```
apps/ios/
├── App/                  앱 진입점 (MarketplaceApp, ContentView, AppEnvironment)
├── DesignSystem/          공용 컴포넌트 (CachedAsyncImage, Theme, Modifiers)
├── Features/              화면별 View + ViewModel
│   ├── Auth/
│   ├── Home/
│   ├── Inbox/
│   ├── ChatRoom/
│   ├── ProductDetail/     ProductDetailView, ProductEditView
│   ├── ProductList/
│   ├── Profile/           ProfileView, ProfileEditView, SettingsView
│   ├── Search/
│   ├── SellNew/
│   └── UploadStatus/
├── Modules/
│   ├── ARPlacementKit/    AR 배치 (footprint-first, plane detection, 치수 라벨)
│   ├── Auth/              AuthManager, KeychainHelper
│   ├── CaptureKit/        SweepCaptureEngine, FrameSelector
│   ├── ModelingKit/       LocalModelBuilder, ModelExportCoordinator (치수 추출)
│   └── Networking/        APIClient, WebSocketManager, ModelDownloader, APIContracts
└── Resources/             Assets, 설정 파일
```

### Seller 플로우

1. SweepCaptureEngine으로 10~20초 스캔 (LiDAR 필수)
2. FrameSelector로 품질/yaw 기반 프레임 선택
3. LocalModelBuilder로 로컬 3D 모델 생성 (PhotogrammetrySession)
4. USDZ export + 썸네일 자동 생성 + 치수 자동 추출 (bounding box)
5. AI 추천: 제목/설명/카테고리/상태/가격범위/치수비교/가격사유 자동 제안 (선택적)
6. uploads/init → presigned upload → uploads/complete (SHA256 checksum 검증)
7. products/publish (asset.status=READY 이후에만 가능)
8. 등록 후 수정/삭제/상태변경 가능 (상세 화면 ellipsis 메뉴)

### Buyer 플로우

1. 상품 목록/검색 → 상세 진입
2. 2D 썸네일 먼저 표시 → "3D로 돌려보기" 버튼으로 opt-in 다운로드
3. Footprint-first AR 배치 (RealityKit) 또는 Quick Look fallback
4. 치수 라벨 표시 (dims.source=ios_lidar → "LiDAR 정밀 스캔 인증됨")
5. 셀러 신뢰 지표 확인 (가입일, 거래횟수)
6. 채팅 또는 구매 → 구매 시 SOLD_OUT 상태 즉시 반영

---

## 테스트

총 102개 테스트. pytest 기반.

```bash
# 전체 테스트
TEST_DATABASE_URL=postgresql://marketplace:marketplace@localhost:5433/marketplace_test \
  uv run pytest tests/ -v

# Lint
cd services/api && uv run ruff check app/
```

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

# API 재빌드 (코드 변경 시)
docker compose -f infra/compose/docker-compose.local.yml up -d --build api
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
