import uuid
from datetime import datetime

from pydantic import BaseModel


class AuthProvidersResponse(BaseModel):
    providers: list[str]


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserResponse"


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    provider: str
    created_at: datetime


class UserSummaryResponse(BaseModel):
    user: UserResponse
    product_count: int
    unread_messages: int
