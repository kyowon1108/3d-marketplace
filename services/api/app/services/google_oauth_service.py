from dataclasses import dataclass

from app.config import settings


@dataclass
class GoogleUserInfo:
    email: str
    name: str
    google_id: str
    avatar_url: str | None


class GoogleOAuthService:
    def __init__(self) -> None:
        self.web_client_id = settings.google_client_id
        self.ios_client_id = settings.google_ios_client_id
        self.client_secret = settings.google_client_secret

    def _valid_audiences(self) -> list[str]:
        audiences = []
        if self.web_client_id:
            audiences.append(self.web_client_id)
        if self.ios_client_id:
            audiences.append(self.ios_client_id)
        return audiences

    def verify_id_token(self, token: str) -> GoogleUserInfo:
        """Verify a Google ID token and extract user info.

        Accepts tokens issued for either web or iOS client IDs.
        Lazy-imports google.auth to avoid startup dependency on `requests` package.
        """
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token

        request = google_requests.Request()

        last_error: Exception | None = None
        for audience in self._valid_audiences():
            try:
                idinfo: dict[str, str] = google_id_token.verify_oauth2_token(  # type: ignore[no-untyped-call]
                    token, request, audience
                )
                return GoogleUserInfo(
                    email=idinfo["email"],
                    name=idinfo.get("name", idinfo["email"]),
                    google_id=idinfo["sub"],
                    avatar_url=idinfo.get("picture"),
                )
            except ValueError as e:
                last_error = e
                continue

        raise ValueError(
            f"Invalid Google ID token: {last_error}"
        )

    def exchange_auth_code(
        self, code: str, redirect_uri: str
    ) -> dict[str, object]:
        """Exchange an authorization code for tokens (web flow)."""
        import httpx

        resp = httpx.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": self.web_client_id,
                "client_secret": self.client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code",
            },
        )
        resp.raise_for_status()
        result: dict[str, object] = resp.json()
        return result
