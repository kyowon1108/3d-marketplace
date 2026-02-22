import uuid
from datetime import datetime

from pydantic import BaseModel


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


class SendMessageRequest(BaseModel):
    body: str


class ChatMessageResponse(BaseModel):
    id: uuid.UUID
    room_id: uuid.UUID
    sender_id: uuid.UUID
    body: str
    created_at: datetime
