import uuid
from datetime import datetime

from pydantic import BaseModel


class FileInitMeta(BaseModel):
    role: str  # MODEL_USDZ | MODEL_GLB | PREVIEW_PNG
    size_bytes: int


class UploadInitRequest(BaseModel):
    dims_source: str | None = None
    dims_width: float | None = None
    dims_height: float | None = None
    dims_depth: float | None = None
    capture_session_id: uuid.UUID | None = None
    files: list[FileInitMeta]


class PresignedUploadTarget(BaseModel):
    role: str
    url: str
    expires_at: datetime


class UploadInitResponse(BaseModel):
    asset_id: uuid.UUID
    status: str
    presigned_uploads: list[PresignedUploadTarget]


class FileCompleteMeta(BaseModel):
    role: str
    size_bytes: int
    checksum_sha256: str


class UploadCompleteRequest(BaseModel):
    asset_id: uuid.UUID
    files: list[FileCompleteMeta]


class FileVerifyResult(BaseModel):
    role: str
    verified: bool


class UploadCompleteResponse(BaseModel):
    asset_id: uuid.UUID
    status: str
    files: list[FileVerifyResult]
