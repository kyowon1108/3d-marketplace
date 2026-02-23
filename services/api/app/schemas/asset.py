import uuid
from datetime import datetime

from pydantic import BaseModel


class AssetFileInfo(BaseModel):
    role: str
    storage_key: str
    size_bytes: int
    checksum_sha256: str


class AssetImageInfo(BaseModel):
    id: uuid.UUID
    image_type: str
    storage_key: str
    size_bytes: int
    sort_order: int


class ModelAssetResponse(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    status: str
    availability: str
    dims_source: str | None = None
    dims_width: float | None = None
    dims_height: float | None = None
    dims_depth: float | None = None
    files: list[AssetFileInfo]
    images: list[AssetImageInfo] = []
    created_at: datetime
    updated_at: datetime


class ArAssetFileInfo(BaseModel):
    role: str
    url: str
    type: str  # "model" | "preview"


class ArAssetResponse(BaseModel):
    availability: str
    asset_id: uuid.UUID | None = None
    files: list[ArAssetFileInfo]
    dims_source: str | None = None
    dims_trust: str | None = None
    dims_width: float | None = None
    dims_height: float | None = None
    dims_depth: float | None = None
