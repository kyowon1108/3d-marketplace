"""WebSocket connection manager for room-based chat broadcast."""

import uuid
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    """Manages WebSocket connections per room for broadcast."""

    def __init__(self) -> None:
        # room_id -> {user_id -> WebSocket}
        self.active_connections: dict[uuid.UUID, dict[uuid.UUID, WebSocket]] = {}

    async def connect(self, room_id: uuid.UUID, user_id: uuid.UUID, ws: WebSocket) -> None:
        if room_id not in self.active_connections:
            self.active_connections[room_id] = {}
        self.active_connections[room_id][user_id] = ws

    def disconnect(self, room_id: uuid.UUID, user_id: uuid.UUID) -> None:
        room = self.active_connections.get(room_id)
        if room:
            room.pop(user_id, None)
            if not room:
                del self.active_connections[room_id]

    async def broadcast_to_room(
        self,
        room_id: uuid.UUID,
        message: dict[str, Any],
        exclude_user_id: uuid.UUID | None = None,
    ) -> None:
        room = self.active_connections.get(room_id, {})
        for uid, ws in list(room.items()):
            if uid == exclude_user_id:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                # Dead connection — clean up
                self.disconnect(room_id, uid)


manager = ConnectionManager()
