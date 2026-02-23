# iOS UX Alignment Evidence — 2026-02-23

## Summary
구매자 우선 MVP 기준으로 iOS 화면 접근성/핵심 전환 흐름/카피 정합성을 정리했다.

## Implemented Changes
1. Home 상단에 검색 진입 버튼 추가 (`ProductListView` toolbar → `SearchView`)
2. SellNew 업로드 완료 카드에 업로드 상태 진입 추가 (`UploadStatusView(assetId:)`)
3. ProductDetail 하단 액션바에 구매 CTA 추가 (`POST /v1/products/{id}/purchase`)
4. 구매 성공/중복구매 시 즉시 `SOLD_OUT` 상태 반영 + 화면 간 동기화 이벤트 추가
5. Product 모델에 `status` 필드 추가 및 리스트/검색/프로필 매핑 반영
6. 판매 폼 카피 수정: `에셋 첨부 (선택)` → `에셋 첨부 (필수)`
7. ProductList 카테고리 범위 정리 및 로컬 정렬/필터 동작 연결 (`최신순`, `인기순`, `무료`)
8. EmptyState 액션을 토스트-only에서 실제 이동 동작으로 수정 (홈/판매 탭 전환)
9. 주요 CTA 접근성 라벨/힌트 보강 (검색, AR, 좋아요, 채팅, 구매, 업로드 상태)
10. Google 로그인 버튼에 준비중 상태를 라벨로 명시

## API Contract Usage
1. `GET /v1/products`
2. `GET /v1/products/{id}`
3. `GET /v1/products/{id}/ar-asset`
4. `POST /v1/products/{id}/chat-rooms`
5. `POST /v1/products/{id}/purchase`
6. `GET /v1/model-assets/{assetId}`

## Files Updated
1. `apps/ios/App/MarketplaceApp.swift`
2. `apps/ios/App/ContentView.swift`
3. `apps/ios/Features/Home/HomeView.swift`
4. `apps/ios/Features/ProductList/ProductListView.swift`
5. `apps/ios/Features/Search/SearchView.swift`
6. `apps/ios/Features/ProductDetail/ProductDetailView.swift`
7. `apps/ios/Features/SellNew/SellNewView.swift`
8. `apps/ios/Features/Inbox/InboxView.swift`
9. `apps/ios/Features/Profile/ProfileView.swift`
10. `apps/ios/Features/Auth/AuthenticationView.swift`
11. `apps/ios/DesignSystem/Components/CategoryPills.swift`
12. `apps/ios/Modules/Networking/APIContracts.swift`
13. `implement/ios/04_web_ios_route_parity_matrix.md`
14. `implement/ios/05_gate_c_checklist.md`

## Validation Status
1. 코드 레벨 정합성 확인 완료 (라우트 연결/타입 추가/상태 동기화 로직 반영)
2. `xcodebuild` 실행 불가 환경으로 디바이스/시뮬레이터 빌드 검증은 미실행
3. 수동 QA는 아래 시나리오 기준으로 후속 수행 필요

## Manual QA Checklist (Pending)
1. 홈 검색 진입 및 검색 결과 상세 진입
2. 업로드 완료 후 업로드 상태 화면 진입/폴링 종료
3. 구매 성공 후 상세/목록 상태 `SOLD_OUT` 동기화
4. 구매 실패(`401/403/400/409`)별 메시지/버튼 상태 확인
5. 빈 상태 CTA의 홈/판매 탭 이동 동작 확인
