import uuid
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.repositories.chat_repo import ChatRepo
from app.repositories.product_repo import ProductRepo
from app.schemas.chat import ChatMessageResponse, ChatRoomResponse


class ChatService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.chat_repo = ChatRepo(db)
        self.product_repo = ProductRepo(db)

    def create_room(
        self,
        product_id: uuid.UUID,
        buyer_id: uuid.UUID,
        subject: str,
    ) -> ChatRoomResponse:
        product = self.product_repo.get_by_id(product_id)
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        room = self.chat_repo.create_room(
            product_id=product_id,
            buyer_id=buyer_id,
            seller_id=product.seller_id,
            subject=subject,
        )
        self.db.commit()

        return ChatRoomResponse(
            id=room.id,
            product_id=room.product_id,
            buyer_id=room.buyer_id,
            seller_id=room.seller_id,
            subject=room.subject,
            created_at=room.created_at,
            last_message_at=room.last_message_at,
        )

    def list_rooms(self, user_id: uuid.UUID) -> list[ChatRoomResponse]:
        rooms = self.chat_repo.list_rooms(user_id)
        return [
            ChatRoomResponse(
                id=r.id,
                product_id=r.product_id,
                buyer_id=r.buyer_id,
                seller_id=r.seller_id,
                subject=r.subject,
                created_at=r.created_at,
                last_message_at=r.last_message_at,
            )
            for r in rooms
        ]

    def get_messages(
        self,
        room_id: uuid.UUID,
        user_id: uuid.UUID,
        before: datetime | None = None,
        limit: int = 50,
    ) -> list[ChatMessageResponse]:
        room = self.chat_repo.get_room(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Chat room not found")
        if room.buyer_id != user_id and room.seller_id != user_id:
            raise HTTPException(status_code=403, detail="Not a participant")

        messages = self.chat_repo.get_messages(room_id, before=before, limit=limit)
        return [
            ChatMessageResponse(
                id=m.id,
                room_id=m.room_id,
                sender_id=m.sender_id,
                body=m.body,
                created_at=m.created_at,
            )
            for m in messages
        ]

    def send_message(
        self,
        room_id: uuid.UUID,
        sender_id: uuid.UUID,
        body: str,
    ) -> ChatMessageResponse:
        room = self.chat_repo.get_room(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Chat room not found")
        if room.buyer_id != sender_id and room.seller_id != sender_id:
            raise HTTPException(status_code=403, detail="Not a participant")

        msg = self.chat_repo.add_message(room_id=room_id, sender_id=sender_id, body=body)
        self.db.commit()

        return ChatMessageResponse(
            id=msg.id,
            room_id=msg.room_id,
            sender_id=msg.sender_id,
            body=msg.body,
            created_at=msg.created_at,
        )
