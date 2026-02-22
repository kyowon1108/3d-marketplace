from unittest.mock import patch

from app.services.jwt_service import JwtService


class TestGoogleOAuthEndpoints:
    @patch("app.services.google_oauth_service.GoogleOAuthService.verify_id_token")
    def test_google_token_exchange_success(self, mock_verify, client, db):
        """iOS sends Google id_token → new user created, JWT pair returned."""
        from app.services.google_oauth_service import GoogleUserInfo

        mock_verify.return_value = GoogleUserInfo(
            email="google@example.com",
            name="Google User",
            google_id="google-uid-123",
            avatar_url="https://example.com/avatar.jpg",
        )

        resp = client.post(
            "/v1/auth/oauth/google/token",
            json={"id_token": "fake-google-id-token"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["access_token"]
        assert data["refresh_token"]
        assert data["user"]["email"] == "google@example.com"
        assert data["user"]["provider"] == "google"

        # Verify JWT is valid
        svc = JwtService()
        payload = svc.decode_access_token(data["access_token"])
        assert payload["email"] == "google@example.com"

    @patch("app.services.google_oauth_service.GoogleOAuthService.verify_id_token")
    def test_google_existing_user_relogin(self, mock_verify, client, db):
        """Existing user re-login returns same user, new JWT pair."""
        from app.services.google_oauth_service import GoogleUserInfo

        mock_verify.return_value = GoogleUserInfo(
            email="returning@example.com",
            name="Returning User",
            google_id="google-uid-456",
            avatar_url=None,
        )

        # First login
        resp1 = client.post(
            "/v1/auth/oauth/google/token",
            json={"id_token": "token-1"},
        )
        assert resp1.status_code == 200
        user_id_1 = resp1.json()["user"]["id"]

        # Second login
        resp2 = client.post(
            "/v1/auth/oauth/google/token",
            json={"id_token": "token-2"},
        )
        assert resp2.status_code == 200
        user_id_2 = resp2.json()["user"]["id"]

        assert user_id_1 == user_id_2  # same user

    @patch("app.services.google_oauth_service.GoogleOAuthService.verify_id_token")
    def test_google_invalid_token_returns_401(self, mock_verify, client, db):
        """Invalid Google ID token → 401."""
        mock_verify.side_effect = ValueError("Token expired")

        resp = client.post(
            "/v1/auth/oauth/google/token",
            json={"id_token": "expired-token"},
        )
        assert resp.status_code == 401

    def test_google_token_exchange_missing_id_token(self, client):
        """Missing id_token → 400."""
        resp = client.post(
            "/v1/auth/oauth/google/token",
            json={},
        )
        assert resp.status_code == 400

    def test_unsupported_provider_token_exchange(self, client):
        """Non-google provider → 400."""
        resp = client.post(
            "/v1/auth/oauth/apple/token",
            json={"id_token": "some-token"},
        )
        assert resp.status_code == 400

    def test_google_in_providers_when_configured(self, client):
        """When google_client_id is set, 'google' appears in providers list."""
        from app.config import settings as real_settings

        original = real_settings.google_client_id
        try:
            real_settings.google_client_id = "some-client-id"
            resp = client.get("/v1/auth/providers")
            assert resp.status_code == 200
            assert "google" in resp.json()["providers"]
        finally:
            real_settings.google_client_id = original

    def test_google_not_in_providers_when_not_configured(self, client):
        """When google_client_id is empty, 'google' is not in providers."""
        from app.config import settings as real_settings

        original = real_settings.google_client_id
        try:
            real_settings.google_client_id = ""
            resp = client.get("/v1/auth/providers")
            assert resp.status_code == 200
            assert "google" not in resp.json()["providers"]
        finally:
            real_settings.google_client_id = original
