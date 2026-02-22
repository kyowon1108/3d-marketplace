import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, user_id: uuid.UUID) -> User | None:
        return self.db.get(User, user_id)

    def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email)
        return self.db.execute(stmt).scalar_one_or_none()

    def create(
        self,
        email: str,
        name: str,
        provider: str = "dev",
        provider_id: str | None = None,
    ) -> User:
        user = User(email=email, name=name, provider=provider, provider_id=provider_id)
        self.db.add(user)
        self.db.flush()
        return user

    def get_or_create(
        self,
        email: str,
        name: str,
        provider: str = "dev",
        provider_id: str | None = None,
    ) -> User:
        existing = self.get_by_email(email)
        if existing:
            return existing
        return self.create(email=email, name=name, provider=provider, provider_id=provider_id)
