import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, field_validator


class CreateChatRoomRequest(BaseModel):
    subject: str


class ChatRoomResponse(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    buyer_id: uuid.UUID
    seller_id: uuid.UUID
    subject: str
    created_at: datetime
    last_message_at: datetime | None = None
    last_message_body: str | None = None
    unread_count: int = 0
    buyer_name: str = ""
    seller_name: str = ""
    product_title: str = ""
    product_thumbnail_url: str | None = None


class SendMessageRequest(BaseModel):
    body: str
    image_url: str | None = None

    @field_validator("image_url")
    @classmethod
    def validate_image_url(cls, v: str | None) -> str | None:
        if v is None:
            return v
        if not v.startswith(("http://", "https://")):
            raise ValueError("image_url must be an HTTP or HTTPS URL")
        return v


class ChatMessageResponse(BaseModel):
    id: uuid.UUID
    room_id: uuid.UUID
    sender_id: uuid.UUID
    body: str
    message_type: Literal["TEXT", "IMAGE"] = "TEXT"
    image_url: str | None = None
    created_at: datetime


class ChatImageUploadResponse(BaseModel):
    image_url: str


class ChatRoomListResponse(BaseModel):
    rooms: list[ChatRoomResponse]


class ChatMessageListResponse(BaseModel):
    messages: list[ChatMessageResponse]
