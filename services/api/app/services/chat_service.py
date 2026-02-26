import uuid
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.chat import ChatRoom
from app.models.enums import ImageType, MessageType
from app.repositories.chat_repo import ChatRepo
from app.repositories.product_repo import ProductRepo
from app.schemas.chat import ChatMessageResponse, ChatRoomResponse
from app.services.storage_service import StorageService

_storage = StorageService()


class ChatService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.chat_repo = ChatRepo(db)
        self.product_repo = ProductRepo(db)

    def _build_room_response(
        self, room: ChatRoom, user_id: uuid.UUID,
    ) -> ChatRoomResponse:
        unread = self.chat_repo.count_unread_for_room(room, user_id)

        buyer_name = ""
        seller_name = ""
        product_title = ""
        product_thumbnail_url: str | None = None

        if room.buyer:
            buyer_name = room.buyer.name or ""
        if room.seller:
            seller_name = room.seller.name or ""
        if room.product:
            product_title = room.product.title or ""
            if room.product.asset and room.product.asset.images:
                for img in sorted(room.product.asset.images, key=lambda i: i.sort_order):
                    if img.image_type == ImageType.THUMBNAIL:
                        product_thumbnail_url = _storage.get_download_url(img.storage_key)
                        break

        return ChatRoomResponse(
            id=room.id,
            product_id=room.product_id,
            buyer_id=room.buyer_id,
            seller_id=room.seller_id,
            subject=room.subject,
            created_at=room.created_at,
            last_message_at=room.last_message_at,
            last_message_body=room.last_message_body,
            unread_count=unread,
            buyer_name=buyer_name,
            seller_name=seller_name,
            product_title=product_title,
            product_thumbnail_url=product_thumbnail_url,
        )

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

        return self._build_room_response(room, buyer_id)

    def list_rooms(self, user_id: uuid.UUID) -> list[ChatRoomResponse]:
        rooms = self.chat_repo.list_rooms(user_id)
        return [self._build_room_response(r, user_id) for r in rooms]

    def mark_read(self, room_id: uuid.UUID, user_id: uuid.UUID) -> ChatRoomResponse:
        room = self.chat_repo.get_room(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Chat room not found")
        if room.buyer_id != user_id and room.seller_id != user_id:
            raise HTTPException(status_code=403, detail="Not a participant")

        self.chat_repo.mark_read(room_id, user_id)
        self.db.commit()
        self.db.refresh(room)

        return self._build_room_response(room, user_id)

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
                message_type=m.message_type or MessageType.TEXT,
                image_url=m.image_url,
                created_at=m.created_at,
            )
            for m in messages
        ]

    def send_message(
        self,
        room_id: uuid.UUID,
        sender_id: uuid.UUID,
        body: str,
        image_url: str | None = None,
    ) -> ChatMessageResponse:
        room = self.chat_repo.get_room(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Chat room not found")
        if room.buyer_id != sender_id and room.seller_id != sender_id:
            raise HTTPException(status_code=403, detail="Not a participant")

        message_type = MessageType.IMAGE if image_url else MessageType.TEXT
        msg = self.chat_repo.add_message(
            room_id=room_id,
            sender_id=sender_id,
            body=body,
            message_type=message_type,
            image_url=image_url,
        )
        self.db.commit()

        return ChatMessageResponse(
            id=msg.id,
            room_id=msg.room_id,
            sender_id=msg.sender_id,
            body=msg.body,
            message_type=msg.message_type or MessageType.TEXT,
            image_url=msg.image_url,
            created_at=msg.created_at,
        )
