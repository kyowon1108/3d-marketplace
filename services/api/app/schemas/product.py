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


class ProductListResponse(BaseModel):
    products: list[ProductResponse]
    total: int
    page: int
    limit: int
