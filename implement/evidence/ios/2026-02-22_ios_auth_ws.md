# iOS Auth + WebSocket Evidence — 2026-02-22

## Summary
Improved iOS auth with refresh token rotation, Google Sign-In button, and WebSocket real-time chat.

## Auth Improvements (Step 10)

### AuthManager Changes
- **Refresh token storage**: Separate Keychain entries for access/refresh tokens
- **`saveTokens(accessToken:, refreshToken:)`**: Stores both tokens
- **`logout()`**: Calls `POST /v1/auth/logout` to revoke refresh token on server, then clears Keychain
- **`currentRefreshToken`**: New computed property for refresh token access

### APIClient Changes
- **401 → auto-refresh**: On 401, attempts `POST /v1/auth/token/refresh` with stored refresh token
- **Retry**: On successful refresh, retries original request with new access token
- **Failure cascade**: If refresh fails, broadcasts `AuthExpired` notification

### APIContracts Additions
- `TokenRefreshRequest`, `TokenRefreshResponse`, `LogoutRequest`, `EmptyResponse`
- `AuthTokenResponse.refresh_token` field (optional)

### Google Sign-In
- Button added to `AuthenticationView` with "Google로 계속하기" label
- Placeholder implementation (actual `ASWebAuthenticationSession` requires real device + OAuth config)

## WebSocket Chat (Step 11)

### WebSocketManager
- `URLSessionWebSocketTask` based
- `?token=<jwt>` query param authentication
- States: `disconnected → connecting → connected → reconnecting`
- Exponential backoff reconnect (1s, 2s, 4s, 8s, 16s), max 5 attempts
- `onMessage` callback for real-time message delivery

### ChatRoomView Integration
- `onAppear`: fetch messages via REST + connect WebSocket
- `onDisappear`: disconnect WebSocket
- WS messages: deduplicated by message ID before appending
- Fallback: if WS disconnected, sends via REST POST
- Connection status: green/red dot in navigation bar
