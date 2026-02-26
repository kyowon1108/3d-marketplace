import uuid
from datetime import datetime

from pydantic import BaseModel, field_validator

from app.models.enums import ProductCategory, ProductCondition

_VALID_CATEGORIES = {e.value for e in ProductCategory}
_VALID_CONDITIONS = {e.value for e in ProductCondition}


class PublishRequest(BaseModel):
    asset_id: uuid.UUID
    title: str
    description: str | None = None
    price_cents: int
    category: str | None = None
    condition: str | None = None
    dims_comparison: str | None = None

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str | None) -> str | None:
        if v is not None and v not in _VALID_CATEGORIES:
            allowed = ", ".join(sorted(_VALID_CATEGORIES))
            raise ValueError(f"Invalid category. Must be one of: {allowed}")
        return v

    @field_validator("condition")
    @classmethod
    def validate_condition(cls, v: str | None) -> str | None:
        if v is not None and v not in _VALID_CONDITIONS:
            allowed = ", ".join(sorted(_VALID_CONDITIONS))
            raise ValueError(f"Invalid condition. Must be one of: {allowed}")
        return v


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
    category: str | None = None
    condition: str | None = None
    dims_comparison: str | None = None
    status: str = "FOR_SALE"
    likes_count: int = 0
    views_count: int = 0
    chat_count: int = 0
    seller_location_name: str | None = None
    seller_joined_at: datetime | None = None
    seller_trade_count: int = 0
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
