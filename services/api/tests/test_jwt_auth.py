import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.config import settings
from app.services.jwt_service import JwtService


class TestJwtService:
    def test_create_and_decode_access_token(self):
        svc = JwtService()
        user_id = uuid.uuid4()
        token = svc.create_access_token(user_id, "test@example.com")

        payload = svc.decode_access_token(token)
        assert payload["sub"] == str(user_id)
        assert payload["email"] == "test@example.com"
        assert payload["type"] == "access"

    def test_create_and_decode_refresh_token(self):
        svc = JwtService()
        user_id = uuid.uuid4()
        token, jti, expires_at = svc.create_refresh_token(user_id)

        payload = svc.decode_refresh_token(token)
        assert payload["sub"] == str(user_id)
        assert payload["jti"] == jti
        assert payload["type"] == "refresh"
        assert expires_at > datetime.now(UTC)

    def test_expired_access_token_raises(self):
        svc = JwtService()
        payload = {
            "sub": str(uuid.uuid4()),
            "email": "test@example.com",
            "type": "access",
            "iat": datetime.now(UTC) - timedelta(hours=2),
            "exp": datetime.now(UTC) - timedelta(hours=1),
        }
        token = jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256")

        with pytest.raises(jwt.ExpiredSignatureError):
            svc.decode_access_token(token)

    def test_refresh_token_not_accepted_as_access(self):
        svc = JwtService()
        user_id = uuid.uuid4()
        token, _, _ = svc.create_refresh_token(user_id)

        with pytest.raises(jwt.InvalidTokenError, match="Not an access token"):
            svc.decode_access_token(token)

    def test_access_token_not_accepted_as_refresh(self):
        svc = JwtService()
        user_id = uuid.uuid4()
        token = svc.create_access_token(user_id, "test@example.com")

        with pytest.raises(jwt.InvalidTokenError, match="Not a refresh token"):
            svc.decode_refresh_token(token)


class TestJwtAuthMiddleware:
    """Test that JWT auth works end-to-end through the API."""

    def test_jwt_auth_me(self, client, test_user):
        """JWT access token should authenticate /v1/auth/me."""
        svc = JwtService()
        token = svc.create_access_token(test_user.id, test_user.email)

        resp = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        assert resp.json()["email"] == test_user.email

    def test_uuid_fallback_still_works(self, client, auth_headers):
        """Dev-mode UUID fallback should still work in test env."""
        resp = client.get("/v1/auth/me", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["email"] == "test@example.com"

    def test_invalid_token_returns_401(self, client):
        resp = client.get("/v1/auth/me", headers={"Authorization": "Bearer invalid-token"})
        assert resp.status_code == 401

    def test_missing_auth_returns_401(self, client):
        resp = client.get("/v1/auth/me")
        assert resp.status_code == 401

    def test_expired_jwt_returns_401(self, client, test_user):
        """Expired JWT should fall back to UUID parse, fail, then 401."""
        payload = {
            "sub": str(test_user.id),
            "email": test_user.email,
            "type": "access",
            "iat": datetime.now(UTC) - timedelta(hours=2),
            "exp": datetime.now(UTC) - timedelta(hours=1),
        }
        token = jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256")
        # This is a JWT string (not a UUID), so UUID fallback also fails
        resp = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 401


class TestTokenRefreshFlow:
    def test_refresh_happy_path(self, client, db):
        """Dev login → get refresh token → use it to get new pair."""
        # Login to get tokens
        resp = client.get("/v1/auth/oauth/dev/callback?code=refresh@test.com:Refresh+User")
        assert resp.status_code == 200
        data = resp.json()
        assert data["refresh_token"] is not None
        refresh_token = data["refresh_token"]

        # Refresh
        resp = client.post(
            "/v1/auth/token/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 200
        new_data = resp.json()
        assert new_data["access_token"]
        assert new_data["refresh_token"]
        assert new_data["refresh_token"] != refresh_token  # rotated
        assert new_data["expires_in"] > 0

    def test_refresh_revoked_token_returns_401(self, client, db):
        """Using a refresh token that was already rotated should fail."""
        resp = client.get("/v1/auth/oauth/dev/callback?code=revoke@test.com:Revoke+User")
        refresh_token = resp.json()["refresh_token"]

        # First refresh (revokes old token)
        resp = client.post(
            "/v1/auth/token/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 200

        # Second refresh with same (now revoked) token
        resp = client.post(
            "/v1/auth/token/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 401

    def test_refresh_invalid_token_returns_401(self, client):
        resp = client.post(
            "/v1/auth/token/refresh",
            json={"refresh_token": "not-a-valid-jwt"},
        )
        assert resp.status_code == 401


class TestLogout:
    def test_logout_revokes_refresh_token(self, client, db):
        """After logout, the refresh token should no longer work."""
        resp = client.get("/v1/auth/oauth/dev/callback?code=logout@test.com:Logout+User")
        refresh_token = resp.json()["refresh_token"]

        # Logout
        resp = client.post("/v1/auth/logout", json={"refresh_token": refresh_token})
        assert resp.status_code == 204

        # Try to use revoked refresh token
        resp = client.post(
            "/v1/auth/token/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 401

    def test_logout_with_invalid_token_succeeds(self, client):
        """Logout with invalid token should not error — idempotent."""
        resp = client.post(
            "/v1/auth/logout",
            json={"refresh_token": "invalid-garbage"},
        )
        assert resp.status_code == 204


class TestDevLoginReturnsJwt:
    def test_dev_login_returns_jwt_pair(self, client):
        resp = client.get("/v1/auth/oauth/dev/callback?code=jwt@test.com:JWT+User")
        assert resp.status_code == 200
        data = resp.json()
        assert data["access_token"]
        assert data["refresh_token"]
        assert data["expires_in"] > 0
        assert data["token_type"] == "bearer"

        # Verify the access token is a valid JWT
        svc = JwtService()
        payload = svc.decode_access_token(data["access_token"])
        assert payload["email"] == "jwt@test.com"
