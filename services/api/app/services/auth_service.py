import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import User
from app.repositories.chat_repo import ChatRepo
from app.repositories.product_repo import ProductRepo
from app.repositories.refresh_token_repo import RefreshTokenRepo
from app.repositories.user_repo import UserRepo
from app.schemas.auth import (
    AuthProvidersResponse,
    AuthTokenResponse,
    TokenRefreshResponse,
    UserResponse,
    UserSummaryResponse,
)
from app.services.google_oauth_service import GoogleOAuthService, GoogleUserInfo
from app.services.jwt_service import JwtService


class AuthService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.user_repo = UserRepo(db)
        self.product_repo = ProductRepo(db)
        self.chat_repo = ChatRepo(db)
        self.refresh_token_repo = RefreshTokenRepo(db)
        self.jwt_service = JwtService()

    def _user_response(self, user: User) -> UserResponse:
        return UserResponse(
            id=user.id,
            email=user.email,
            name=user.name,
            provider=user.provider,
            avatar_url=user.avatar_url,
            location_name=user.location_name,
            created_at=user.created_at,
        )

    def _create_token_response(self, user: User) -> AuthTokenResponse:
        """Generate JWT access + refresh tokens for a user."""
        access_token = self.jwt_service.create_access_token(user.id, user.email)
        refresh_token, jti, expires_at = self.jwt_service.create_refresh_token(user.id)

        # Persist refresh token
        self.refresh_token_repo.create(
            user_id=user.id,
            jti=jti,
            expires_at=expires_at,
        )

        return AuthTokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.jwt_access_token_expire_minutes * 60,
            user=self._user_response(user),
        )

    def get_providers(self) -> AuthProvidersResponse:
        providers: list[str] = []
        if settings.dev_auth_enabled:
            providers.append("dev")
        if settings.google_client_id:
            providers.append("google")
        return AuthProvidersResponse(providers=providers)

    def dev_login(self, email: str, name: str) -> AuthTokenResponse:
        """Dev-only login: create or get user, return JWT tokens."""
        user = self.user_repo.get_or_create(email=email, name=name, provider="dev")
        self.db.commit()
        response = self._create_token_response(user)
        self.db.commit()
        return response

    def google_login_with_id_token(self, id_token: str) -> AuthTokenResponse:
        """Verify Google ID token and return JWT tokens."""
        google_svc = GoogleOAuthService()
        try:
            google_user: GoogleUserInfo = google_svc.verify_id_token(id_token)
        except ValueError as e:
            raise HTTPException(status_code=401, detail=str(e))

        user = self.user_repo.get_or_create(
            email=google_user.email,
            name=google_user.name,
            provider="google",
            provider_id=google_user.google_id,
        )
        if google_user.avatar_url and not user.avatar_url:
            user.avatar_url = google_user.avatar_url
        self.db.commit()

        response = self._create_token_response(user)
        self.db.commit()
        return response

    def google_login_with_code(
        self, code: str, redirect_uri: str
    ) -> AuthTokenResponse:
        """Exchange Google auth code for tokens, then create JWT."""
        google_svc = GoogleOAuthService()
        try:
            token_data = google_svc.exchange_auth_code(code, redirect_uri)
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Google auth code exchange failed: {e}")

        raw_id_token = token_data.get("id_token")
        if not raw_id_token:
            raise HTTPException(status_code=401, detail="No id_token in Google response")

        return self.google_login_with_id_token(str(raw_id_token))

    def refresh_tokens(self, refresh_token: str) -> TokenRefreshResponse:
        """Rotate refresh token: revoke old, issue new pair."""
        try:
            payload = self.jwt_service.decode_refresh_token(refresh_token)
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        jti = str(payload.get("jti", ""))
        if not jti:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        # Check if token exists and is not revoked
        stored = self.refresh_token_repo.find_by_jti(jti)
        if not stored or stored.revoked_at is not None:
            raise HTTPException(status_code=401, detail="Refresh token revoked or not found")

        # Revoke old token
        self.refresh_token_repo.revoke(jti)

        # Issue new pair
        user_id = uuid.UUID(str(payload["sub"]))
        user = self.user_repo.get_by_id(user_id)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        new_access = self.jwt_service.create_access_token(user.id, user.email)
        new_refresh, new_jti, new_expires = self.jwt_service.create_refresh_token(user.id)
        self.refresh_token_repo.create(
            user_id=user.id,
            jti=new_jti,
            expires_at=new_expires,
        )
        self.db.commit()

        return TokenRefreshResponse(
            access_token=new_access,
            refresh_token=new_refresh,
            token_type="bearer",
            expires_in=settings.jwt_access_token_expire_minutes * 60,
        )

    def logout(self, refresh_token: str) -> None:
        """Revoke the given refresh token."""
        try:
            payload = self.jwt_service.decode_refresh_token(refresh_token)
        except Exception:
            # If token is invalid/expired, nothing to revoke — that's fine
            return

        jti = str(payload.get("jti", ""))
        if jti:
            self.refresh_token_repo.revoke(jti)
            self.db.commit()

    def get_user_response(self, user_id: uuid.UUID) -> UserResponse | None:
        user = self.user_repo.get_by_id(user_id)
        if not user:
            return None
        return self._user_response(user)

    def get_user_summary(self, user_id: uuid.UUID) -> UserSummaryResponse | None:
        user = self.user_repo.get_by_id(user_id)
        if not user:
            return None
        product_count = self.product_repo.count_by_seller(user_id)
        unread = self.chat_repo.count_unread_for_user(user_id)
        return UserSummaryResponse(
            user=self._user_response(user),
            product_count=product_count,
            unread_messages=unread,
        )
