import uuid
from datetime import UTC, datetime, timedelta

import jwt

from app.config import settings


class JwtService:
    def __init__(self) -> None:
        self.secret_key = settings.jwt_secret_key
        self.algorithm = settings.jwt_algorithm
        self.access_token_expire_minutes = settings.jwt_access_token_expire_minutes
        self.refresh_token_expire_days = settings.jwt_refresh_token_expire_days

    def create_access_token(self, user_id: uuid.UUID, email: str) -> str:
        now = datetime.now(UTC)
        payload = {
            "sub": str(user_id),
            "email": email,
            "type": "access",
            "iat": now,
            "exp": now + timedelta(minutes=self.access_token_expire_minutes),
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)

    def create_refresh_token(
        self, user_id: uuid.UUID
    ) -> tuple[str, str, datetime]:
        """Create a refresh token. Returns (token, jti, expires_at)."""
        now = datetime.now(UTC)
        jti = str(uuid.uuid4())
        expires_at = now + timedelta(days=self.refresh_token_expire_days)
        payload = {
            "sub": str(user_id),
            "jti": jti,
            "type": "refresh",
            "iat": now,
            "exp": expires_at,
        }
        token = jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
        return token, jti, expires_at

    def decode_access_token(self, token: str) -> dict[str, object]:
        """Decode and verify an access token."""
        payload = jwt.decode(
            token, self.secret_key, algorithms=[self.algorithm]
        )
        if payload.get("type") != "access":
            raise jwt.InvalidTokenError("Not an access token")
        return payload

    def decode_refresh_token(self, token: str) -> dict[str, object]:
        """Decode and verify a refresh token."""
        payload = jwt.decode(
            token, self.secret_key, algorithms=[self.algorithm]
        )
        if payload.get("type") != "refresh":
            raise jwt.InvalidTokenError("Not a refresh token")
        return payload
