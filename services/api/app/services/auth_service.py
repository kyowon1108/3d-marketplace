import uuid

from sqlalchemy.orm import Session

from app.repositories.chat_repo import ChatRepo
from app.repositories.product_repo import ProductRepo
from app.repositories.user_repo import UserRepo
from app.schemas.auth import (
    AuthProvidersResponse,
    AuthTokenResponse,
    UserResponse,
    UserSummaryResponse,
)


class AuthService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.user_repo = UserRepo(db)
        self.product_repo = ProductRepo(db)
        self.chat_repo = ChatRepo(db)

    def get_providers(self) -> AuthProvidersResponse:
        return AuthProvidersResponse(providers=["dev"])

    def dev_login(self, email: str, name: str) -> AuthTokenResponse:
        """Dev-only login: create or get user, return a simple token."""
        user = self.user_repo.get_or_create(email=email, name=name, provider="dev")
        self.db.commit()
        # Simple token = user ID (dev only, not for production)
        token = str(user.id)
        return AuthTokenResponse(
            access_token=token,
            user=UserResponse(
                id=user.id,
                email=user.email,
                name=user.name,
                provider=user.provider,
                created_at=user.created_at,
            ),
        )

    def get_user_response(self, user_id: uuid.UUID) -> UserResponse | None:
        user = self.user_repo.get_by_id(user_id)
        if not user:
            return None
        return UserResponse(
            id=user.id,
            email=user.email,
            name=user.name,
            provider=user.provider,
            created_at=user.created_at,
        )

    def get_user_summary(self, user_id: uuid.UUID) -> UserSummaryResponse | None:
        user = self.user_repo.get_by_id(user_id)
        if not user:
            return None
        product_count = self.product_repo.count_by_seller(user_id)
        unread = self.chat_repo.count_unread_for_user(user_id)
        return UserSummaryResponse(
            user=UserResponse(
                id=user.id,
                email=user.email,
                name=user.name,
                provider=user.provider,
                created_at=user.created_at,
            ),
            product_count=product_count,
            unread_messages=unread,
        )
