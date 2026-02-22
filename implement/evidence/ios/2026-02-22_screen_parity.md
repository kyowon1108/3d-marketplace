# iOS Screen Parity Evidence — 2026-02-22

## Summary
All 11 iOS screens implemented with route parity to web. Structure/copy/state match verified.

## Screen Parity Matrix

| Web Route | iOS Screen | File | Status | Notes |
|---|---|---|---|---|
| `/` | Home | `Features/Home/HomeView.swift` | PASS | Grid layout, ProductCard, search NavigationLink |
| `/products` | Product List | `Features/ProductList/ProductListView.swift` | PASS | Grid, pagination, search query |
| `/products/[id]` | Product Detail | `Features/ProductDetail/ProductDetailView.swift` | PASS | AR CTA, like, chat, dims_trust, ARPlacementView (iOS 17+) with ARQuickLook fallback |
| `/search` | Search | `Features/Search/SearchView.swift` | PASS | **NEW** — SearchBar + recent searches (UserDefaults) + query results grid |
| `/app/sell/new` | Sell New | `Features/SellNew/SellNewView.swift` + `SellNewViewModel.swift` | PASS | Refactored to use LocalModelBuilder from ModelingKit |
| `/app/reconstructions/[jobId]` | Upload Status | `Features/SellNew/UploadStatusView.swift` | PASS | **NEW** — 3s polling, status circle, terminal state detection |
| `/app/inbox` | Inbox | `Features/Inbox/InboxView.swift` | PASS | Chat room list with unread dots |
| `/app/inbox/[roomId]` | Chat Room | `Features/Inbox/ChatRoomView.swift` | PASS | WebSocket real-time + REST fallback, connection status dot |
| `/app/profile` | Profile | `Features/Profile/ProfileView.swift` | PASS | .refreshable, logout confirmation dialog |
| `/auth/login` | Login | `Features/Auth/AuthenticationView.swift` | PASS | Google Sign-In button added |
| `/auth/signup` | Signup | Features/Auth/AuthenticationView.swift | PASS | Same view, toggle mode |

## Kit Extraction

| Module | Files | Purpose |
|---|---|---|
| CaptureKit | `SweepCaptureEngine.swift`, `FrameSelector.swift` | ObjectCaptureSession lifecycle |
| ModelingKit | `LocalModelBuilder.swift`, `ModelExportCoordinator.swift` | PhotogrammetrySession + progress |
| ARPlacementKit | `ARPlacementView.swift`, `FootprintIndicator.swift`, `GestureController.swift` | RealityKit AR placement |

## Backend WebSocket

| Test | Status | Description |
|---|---|---|
| `test_ws_auth_missing_token` | PASS | Close 4001 |
| `test_ws_auth_invalid_token` | PASS | Close 4001 |
| `test_ws_not_participant` | PASS | Close 4003 |
| `test_ws_message_persistence` | PASS | WS send → GET messages confirmed |
| `test_ws_broadcast_two_clients` | PASS | seller sends → buyer receives |
| `test_ws_disconnect_cleanup` | PASS | Graceful disconnect + reconnect |
| `test_e2e_seller_flow` | PASS | 11 API calls end-to-end |

## Validation Commands
```bash
# Backend: 66 passed
uv run pytest tests/ -v

# Ruff: only pre-existing issue in refresh_token_repo.py
uv run ruff check app/ tests/
```
