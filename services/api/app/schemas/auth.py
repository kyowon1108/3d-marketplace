import uuid
from datetime import datetime

from pydantic import BaseModel


class AuthProvidersResponse(BaseModel):
    providers: list[str]


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int | None = None
    user: "UserResponse"


class TokenRefreshRequest(BaseModel):
    refresh_token: str


class TokenRefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class LogoutRequest(BaseModel):
    refresh_token: str


class GoogleTokenRequest(BaseModel):
    id_token: str | None = None
    code: str | None = None


class UserUpdateRequest(BaseModel):
    name: str | None = None
    location_name: str | None = None


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    provider: str
    avatar_url: str | None = None
    location_name: str | None = None
    created_at: datetime


class UserSummaryResponse(BaseModel):
    user: UserResponse
    product_count: int
    unread_messages: int
