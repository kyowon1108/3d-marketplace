import uuid
from datetime import UTC, datetime

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.chat import ChatMessage, ChatRoom


class ChatRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create_room(
        self,
        product_id: uuid.UUID,
        buyer_id: uuid.UUID,
        seller_id: uuid.UUID,
        subject: str,
    ) -> ChatRoom:
        room = ChatRoom(
            product_id=product_id,
            buyer_id=buyer_id,
            seller_id=seller_id,
            subject=subject,
        )
        self.db.add(room)
        self.db.flush()
        return room

    def list_rooms(self, user_id: uuid.UUID) -> list[ChatRoom]:
        stmt = (
            select(ChatRoom)
            .where(or_(ChatRoom.buyer_id == user_id, ChatRoom.seller_id == user_id))
            .order_by(ChatRoom.last_message_at.desc().nullslast(), ChatRoom.created_at.desc())
        )
        return list(self.db.execute(stmt).scalars().all())

    def get_room(self, room_id: uuid.UUID) -> ChatRoom | None:
        return self.db.get(ChatRoom, room_id)

    def get_messages(
        self,
        room_id: uuid.UUID,
        before: datetime | None = None,
        limit: int = 50,
    ) -> list[ChatMessage]:
        stmt = select(ChatMessage).where(ChatMessage.room_id == room_id)
        if before:
            stmt = stmt.where(ChatMessage.created_at < before)
        stmt = stmt.order_by(ChatMessage.created_at.desc()).limit(limit)
        return list(self.db.execute(stmt).scalars().all())

    def add_message(
        self,
        room_id: uuid.UUID,
        sender_id: uuid.UUID,
        body: str,
    ) -> ChatMessage:
        msg = ChatMessage(room_id=room_id, sender_id=sender_id, body=body)
        self.db.add(msg)
        self.db.flush()

        # Update room's last_message_at and last_message_body
        room = self.db.get(ChatRoom, room_id)
        if room:
            room.last_message_at = datetime.now(UTC)
            room.last_message_body = body
            self.db.flush()

        return msg

    def is_participant(self, room_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        room = self.db.get(ChatRoom, room_id)
        if not room:
            return False
        return room.buyer_id == user_id or room.seller_id == user_id

    def count_unread_for_room(self, room: ChatRoom, user_id: uuid.UUID) -> int:
        """Count messages after the user's last_read_at timestamp."""
        if user_id == room.buyer_id:
            last_read = room.buyer_last_read_at
        elif user_id == room.seller_id:
            last_read = room.seller_last_read_at
        else:
            return 0

        stmt = (
            select(func.count())
            .select_from(ChatMessage)
            .where(
                ChatMessage.room_id == room.id,
                ChatMessage.sender_id != user_id,
            )
        )
        if last_read is not None:
            stmt = stmt.where(ChatMessage.created_at > last_read)

        return self.db.execute(stmt).scalar_one()

    def mark_read(self, room_id: uuid.UUID, user_id: uuid.UUID) -> ChatRoom | None:
        """Set the appropriate *_last_read_at to now()."""
        room = self.db.get(ChatRoom, room_id)
        if not room:
            return None

        now = datetime.now(UTC)
        if user_id == room.buyer_id:
            room.buyer_last_read_at = now
        elif user_id == room.seller_id:
            room.seller_last_read_at = now
        else:
            return None

        self.db.flush()
        return room

    def count_unread_for_user(self, user_id: uuid.UUID) -> int:
        """Total unread messages across all rooms the user participates in."""
        rooms = self.list_rooms(user_id)
        return sum(self.count_unread_for_room(r, user_id) for r in rooms)
