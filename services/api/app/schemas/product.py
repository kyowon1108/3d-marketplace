import uuid
from datetime import datetime

from pydantic import BaseModel


class PublishRequest(BaseModel):
    asset_id: uuid.UUID
    title: str
    description: str | None = None
    price_cents: int


class ProductUpdateRequest(BaseModel):
    title: str | None = None
    description: str | None = None
    price_cents: int | None = None


class StatusChangeRequest(BaseModel):
    status: str


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


class PurchaseResponse(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    buyer_id: uuid.UUID
    price_cents: int
    purchased_at: datetime
    product: ProductResponse | None = None


class PurchaseListResponse(BaseModel):
    purchases: list[PurchaseResponse]
    total: int
    page: int
    limit: int
