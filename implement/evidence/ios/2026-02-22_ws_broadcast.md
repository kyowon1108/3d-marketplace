# WebSocket Broadcast + Auth Evidence — 2026-02-22

## Summary
Replaced echo WebSocket with authenticated, room-based broadcast with message persistence.

## Changes

### New Files
- `services/api/app/services/connection_manager.py` — Room-based WS connection manager (singleton)
- `services/api/tests/test_e2e_seller_flow.py` — Full 11-API-call seller journey test

### Modified Files
- `services/api/app/routers/chat.py` — JWT auth via `?token=` query param, participant check, DB persist + broadcast
- `services/api/app/repositories/chat_repo.py` — Added `is_participant()` method
- `services/api/tests/test_websocket.py` — 6 tests: auth, broadcast, persistence, cleanup

## Auth Flow
1. Client connects with `?token=<jwt_or_uuid>` query param
2. `_resolve_user_from_token()` validates (JWT first, UUID fallback in dev)
3. `ChatRepo.is_participant()` verifies room membership
4. Close codes: 4001 (no/invalid token), 4003 (not participant)

## Broadcast Flow
1. Client sends `{"body": "text"}` via WebSocket
2. Server persists to `chat_messages` table via `ChatRepo.add_message()`
3. Server broadcasts to ALL room participants (including sender)
4. On disconnect, user removed from `active_connections`

## Test Results
```
66 passed, 26 warnings in 6.25s
```
