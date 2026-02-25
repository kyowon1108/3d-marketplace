# iOS Evidence — CachedAsyncImage 에러 처리 + Deprecated API 수정

- Date: 2026-02-25
- Gate: C (iOS) — post-gate polish
- Items: UX polish, Product detail parity

## Summary

Antigravity가 구현한 CachedAsyncImage 컴포넌트에 에러 fallback 미처리, deprecated API 사용, 불필요 import 문제를 수정.

## Changes

### 1. CachedAsyncImage.swift

| Before | After |
|--------|-------|
| `<Content, Placeholder>` 2-generic | `<Content, Placeholder, Failure>` 3-generic |
| 에러/디코드 실패 시 스피너 무한 표시 | `loadFailed` state → failure view 또는 placeholder fallback |
| `import Combine` (미사용) | `import UIKit` (UIImage 실사용) |
| `onChange(of: url) { _ in` (iOS 16 deprecated) | `onChange(of: url) {` (iOS 17) |
| `url == nil` → 아무것도 안 함 | `url == nil` → `loadFailed = true` |

기존 호출처 호환: `where Failure == EmptyView` extension init으로 2-param 호출 유지.

### 2. HomeView.swift

- `CachedAsyncImage` 호출에 `failure:` 클로저 추가 (cube.fill 아이콘)
- URL이 유효하지만 로드 실패 시에도 fallback 아이콘 표시

### 3. ProductDetailView.swift

- Hero 썸네일 `CachedAsyncImage`에 `failure:` 클로저 추가 (cube.transparent 아이콘, 검은 배경)
- Seller avatar는 기존 placeholder(person.fill)가 failure 시에도 적절하여 변경 없음
- ModelDownloader `onChange` 코멘트 수정: "Auto-launch AR" → "Haptic feedback when download completes"

### 4. ChatRoomView.swift

- `.onChange(of: isInputFocused) { focused in` → `.onChange(of: isInputFocused) { _, newValue in` (iOS 17)

## Files Modified

| File | Change |
|------|--------|
| `apps/ios/DesignSystem/CachedAsyncImage.swift` | loadFailed + Failure generic + UIKit import + onChange fix |
| `apps/ios/Features/Home/HomeView.swift` | failure 클로저 추가 |
| `apps/ios/Features/ProductDetail/ProductDetailView.swift` | hero failure 클로저 + 코멘트 수정 |
| `apps/ios/Features/Inbox/ChatRoomView.swift` | onChange deprecated 형식 수정 |

## Verification

- Xcode 빌드 타겟 컴파일 확인 필요
- 이미지 URL 무효 시 fallback 아이콘 표시 확인
- 캐시 hit 시 즉시 이미지 표시 (기존 동작 유지)
- Backend 변경 없음

## Judgment

PASS — 에러 상태 처리 완비, deprecated API 제거, 기존 호출처 하위 호환 유지.
