import json
import uuid
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.database import SessionLocal, get_db
from app.middleware.auth import get_current_user, resolve_user_from_token
from app.models.user import User
from app.repositories.chat_repo import ChatRepo
from app.schemas.chat import ChatMessageResponse, ChatRoomResponse, SendMessageRequest
from app.services.chat_service import ChatService
from app.services.connection_manager import manager

router = APIRouter(tags=["chat"])


@router.get("/v1/chat-rooms", response_model=dict[str, Any])
def list_chat_rooms(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    svc = ChatService(db)
    rooms = svc.list_rooms(user.id)
    return {"rooms": rooms}


@router.post("/v1/chat-rooms/{room_id}/read", response_model=ChatRoomResponse)
def mark_room_read(
    room_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatRoomResponse:
    svc = ChatService(db)
    return svc.mark_read(room_id=room_id, user_id=user.id)


@router.get("/v1/chat-rooms/{room_id}/messages", response_model=dict[str, Any])
def get_chat_messages(
    room_id: uuid.UUID,
    before: datetime | None = None,
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    svc = ChatService(db)
    messages = svc.get_messages(room_id=room_id, user_id=user.id, before=before, limit=limit)
    return {"messages": messages}


@router.post(
    "/v1/chat-rooms/{room_id}/messages",
    response_model=ChatMessageResponse,
    status_code=201,
)
def send_chat_message(
    room_id: uuid.UUID,
    body: SendMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatMessageResponse:
    svc = ChatService(db)
    return svc.send_message(room_id=room_id, sender_id=user.id, body=body.body)


@router.websocket("/v1/chats/{room_id}")
async def websocket_chat(
    websocket: WebSocket, room_id: uuid.UUID, token: str | None = None,
) -> None:
    # --- Auth ---
    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return

    db = SessionLocal()
    try:
        user = resolve_user_from_token(token, db)
        if not user:
            await websocket.close(code=4001, reason="Invalid token")
            return

        # --- Participant check ---
        chat_repo = ChatRepo(db)
        if not chat_repo.is_participant(room_id, user.id):
            await websocket.close(code=4003, reason="Not a participant")
            return

        await websocket.accept()
        await manager.connect(room_id, user.id, websocket)

        # Auto-mark read on connect
        chat_repo.mark_read(room_id, user.id)
        db.commit()

        try:
            while True:
                data = await websocket.receive_text()
                try:
                    msg = json.loads(data)
                except json.JSONDecodeError:
                    continue
                body = msg.get("body", "")
                if not body:
                    continue

                # Persist to DB
                chat_msg = chat_repo.add_message(
                    room_id=room_id, sender_id=user.id, body=body
                )
                db.commit()

                # Auto-mark read for the sender
                chat_repo.mark_read(room_id, user.id)

                # Broadcast to all room participants
                broadcast_payload = {
                    "type": "message",
                    "id": str(chat_msg.id),
                    "room_id": str(room_id),
                    "sender_id": str(user.id),
                    "body": body,
                    "created_at": chat_msg.created_at.isoformat(),
                }
                await manager.broadcast_to_room(room_id, broadcast_payload)
        except WebSocketDisconnect:
            pass
        finally:
            manager.disconnect(room_id, user.id)
    finally:
        db.close()
