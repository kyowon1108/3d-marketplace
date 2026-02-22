import uuid
from datetime import datetime

from pydantic import BaseModel


class FileInitMeta(BaseModel):
    role: str  # MODEL_USDZ | MODEL_GLB | PREVIEW_PNG
    size_bytes: int


class ImageInitMeta(BaseModel):
    image_type: str  # THUMBNAIL | DISPLAY
    sort_order: int = 0
    size_bytes: int


class UploadInitRequest(BaseModel):
    dims_source: str | None = None
    dims_width: float | None = None
    dims_height: float | None = None
    dims_depth: float | None = None
    capture_session_id: uuid.UUID | None = None
    files: list[FileInitMeta]
    images: list[ImageInitMeta] = []


class PresignedUploadTarget(BaseModel):
    role: str
    url: str
    expires_at: datetime


class PresignedImageTarget(BaseModel):
    image_type: str
    sort_order: int
    url: str
    expires_at: datetime


class UploadInitResponse(BaseModel):
    asset_id: uuid.UUID
    status: str
    presigned_uploads: list[PresignedUploadTarget]
    presigned_image_uploads: list[PresignedImageTarget] = []


class FileCompleteMeta(BaseModel):
    role: str
    size_bytes: int
    checksum_sha256: str


class ImageCompleteMeta(BaseModel):
    image_type: str
    sort_order: int
    size_bytes: int
    checksum_sha256: str


class UploadCompleteRequest(BaseModel):
    asset_id: uuid.UUID
    files: list[FileCompleteMeta]
    images: list[ImageCompleteMeta] = []


class FileVerifyResult(BaseModel):
    role: str
    verified: bool


class ImageVerifyResult(BaseModel):
    image_type: str
    sort_order: int
    verified: bool


class UploadCompleteResponse(BaseModel):
    asset_id: uuid.UUID
    status: str
    files: list[FileVerifyResult]
    image_results: list[ImageVerifyResult] = []
