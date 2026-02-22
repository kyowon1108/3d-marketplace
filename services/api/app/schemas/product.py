import uuid
from datetime import datetime

from pydantic import BaseModel


class PublishRequest(BaseModel):
    asset_id: uuid.UUID
    title: str
    description: str | None = None
    price_cents: int


class ProductResponse(BaseModel):
    id: uuid.UUID
    asset_id: uuid.UUID | None = None
    title: str
    description: str | None = None
    price_cents: int
    seller_id: uuid.UUID
    published_at: datetime | None = None
    created_at: datetime
    seller_name: str = ""
    seller_avatar_url: str | None = None
    thumbnail_url: str | None = None
    status: str = "FOR_SALE"
    likes_count: int = 0
    views_count: int = 0
    chat_count: int = 0
    seller_location_name: str | None = None
    is_liked: bool | None = None


class ProductListResponse(BaseModel):
    products: list[ProductResponse]
    total: int
    page: int
    limit: int


class LikeToggleResponse(BaseModel):
    liked: bool
    likes_count: int
