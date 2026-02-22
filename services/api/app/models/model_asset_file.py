from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.enums import FileRole

if TYPE_CHECKING:
    from app.models.model_asset import ModelAsset


class ModelAssetFile(Base):
    __tablename__ = "model_asset_files"
    __table_args__ = (
        UniqueConstraint("asset_id", "file_role", name="uq_asset_file_role"),
        UniqueConstraint("storage_key", name="uq_storage_key"),
        Index("ix_model_asset_files_asset_id", "asset_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    asset_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("model_assets.id"), nullable=False)
    file_role: Mapped[FileRole] = mapped_column(String(20), nullable=False)
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    checksum_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    asset: Mapped[ModelAsset] = relationship(back_populates="files")
