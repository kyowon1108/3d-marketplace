import json
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.database import get_db
from app.middleware.auth import get_current_user
from app.models.user import User
from app.schemas.chat import ChatMessageResponse, SendMessageRequest
from app.services.chat_service import ChatService

router = APIRouter(tags=["chat"])


@router.get("/v1/chat-rooms", response_model=dict)
def list_chat_rooms(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    svc = ChatService(db)
    rooms = svc.list_rooms(user.id)
    return {"rooms": rooms}


@router.get("/v1/chat-rooms/{room_id}/messages", response_model=dict)
def get_chat_messages(
    room_id: uuid.UUID,
    before: datetime | None = None,
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
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
async def websocket_chat(websocket: WebSocket, room_id: uuid.UUID) -> None:
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            # Echo back for now — real implementation would broadcast
            msg = json.loads(data)
            await websocket.send_json(
                {"type": "message", "room_id": str(room_id), "body": msg.get("body", "")}
            )
    except WebSocketDisconnect:
        pass
