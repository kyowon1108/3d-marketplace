import json
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.database import SessionLocal, get_db
from app.middleware.auth import get_current_user, resolve_user_from_token
from app.models.enums import MessageType
from app.models.user import User
from app.repositories.chat_repo import ChatRepo
from app.schemas.chat import (
    ChatImageUploadResponse,
    ChatMessageListResponse,
    ChatMessageResponse,
    ChatRoomListResponse,
    ChatRoomResponse,
    SendMessageRequest,
)
from app.services.chat_service import ChatService
from app.services.connection_manager import manager

router = APIRouter(tags=["chat"])

_MAX_UPLOAD_SIZE = 20 * 1024 * 1024  # 20 MB

_ALLOWED_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

# Magic byte signatures for image formats
_MAGIC_SIGNATURES: list[tuple[bytes, str]] = [
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
    (b"RIFF", "image/webp"),  # WebP starts with RIFF....WEBP
]


def _detect_content_type(data: bytes) -> str | None:
    """Detect image content type from magic bytes."""
    for magic, ct in _MAGIC_SIGNATURES:
        if data[:len(magic)] == magic:
            if ct == "image/webp" and data[8:12] != b"WEBP":
                continue
            return ct
    return None


@router.get("/v1/chat-rooms", response_model=ChatRoomListResponse)
def list_chat_rooms(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatRoomListResponse:
    svc = ChatService(db)
    rooms = svc.list_rooms(user.id)
    return ChatRoomListResponse(rooms=rooms)


@router.post("/v1/chat-rooms/{room_id}/read", response_model=ChatRoomResponse)
def mark_room_read(
    room_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatRoomResponse:
    svc = ChatService(db)
    return svc.mark_read(room_id=room_id, user_id=user.id)


@router.get("/v1/chat-rooms/{room_id}/messages", response_model=ChatMessageListResponse)
def get_chat_messages(
    room_id: uuid.UUID,
    before: datetime | None = None,
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatMessageListResponse:
    svc = ChatService(db)
    messages = svc.get_messages(room_id=room_id, user_id=user.id, before=before, limit=limit)
    return ChatMessageListResponse(messages=messages)


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
    return svc.send_message(
        room_id=room_id, sender_id=user.id, body=body.body, image_url=body.image_url,
    )


@router.post("/v1/chat-images/upload", response_model=ChatImageUploadResponse)
async def upload_chat_image(
    file: UploadFile,
    user: User = Depends(get_current_user),
) -> ChatImageUploadResponse:
    """Upload a chat image (AR screenshot, etc.) and return its URL."""
    # Validate content type from header
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file.content_type}. Allowed: JPEG, PNG, WebP.",
        )

    # Read with size limit (chunked to prevent OOM)
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await file.read(1024 * 64)  # 64KB chunks
        if not chunk:
            break
        total += len(chunk)
        if total > _MAX_UPLOAD_SIZE:
            raise HTTPException(status_code=413, detail="File too large. Maximum size is 20MB.")
        chunks.append(chunk)
    data = b"".join(chunks)

    if not data:
        raise HTTPException(status_code=400, detail="Empty file.")

    # Validate magic bytes
    detected_type = _detect_content_type(data)
    if detected_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail="File content does not match an allowed image format (JPEG, PNG, WebP).",
        )

    ext = _ALLOWED_CONTENT_TYPES[detected_type]

    from app.services.storage_service import StorageService

    storage = StorageService()
    key = f"chat-images/{uuid.uuid4()}{ext}"
    storage.save_file(key, data)
    return ChatImageUploadResponse(image_url=storage.get_download_url(key))


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
                image_url = msg.get("image_url")

                # Validate image_url: must be http(s) or discard
                if image_url and not isinstance(image_url, str):
                    image_url = None
                if image_url and not image_url.startswith(("http://", "https://")):
                    image_url = None

                if not body and not image_url:
                    continue

                message_type = MessageType.IMAGE if image_url else MessageType.TEXT
                if not body:
                    body = "[사진]"

                # Persist to DB
                chat_msg = chat_repo.add_message(
                    room_id=room_id,
                    sender_id=user.id,
                    body=body,
                    message_type=message_type,
                    image_url=image_url,
                )
                db.commit()

                # Auto-mark read for the sender
                chat_repo.mark_read(room_id, user.id)
                db.commit()

                # Broadcast to all room participants
                broadcast_payload = {
                    "type": "message",
                    "id": str(chat_msg.id),
                    "room_id": str(room_id),
                    "sender_id": str(user.id),
                    "body": body,
                    "message_type": message_type,
                    "image_url": image_url,
                    "created_at": chat_msg.created_at.isoformat(),
                }
                await manager.broadcast_to_room(room_id, broadcast_payload)
        except WebSocketDisconnect:
            pass
        finally:
            manager.disconnect(room_id, user.id)
    finally:
        db.close()
