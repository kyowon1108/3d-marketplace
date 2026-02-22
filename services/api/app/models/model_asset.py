from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Float, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.enums import AssetStatus, DimsSource

if TYPE_CHECKING:
    from app.models.capture_session import CaptureSession
    from app.models.model_asset_file import ModelAssetFile
    from app.models.user import User


class ModelAsset(Base):
    __tablename__ = "model_assets"
    __table_args__ = (
        Index("ix_model_assets_owner_status", "owner_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    status: Mapped[AssetStatus] = mapped_column(
        String(20), nullable=False, default=AssetStatus.INITIATED
    )
    dims_source: Mapped[DimsSource | None] = mapped_column(String(20), nullable=True)
    dims_width: Mapped[float | None] = mapped_column(Float, nullable=True)
    dims_height: Mapped[float | None] = mapped_column(Float, nullable=True)
    dims_depth: Mapped[float | None] = mapped_column(Float, nullable=True)
    capture_session_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("capture_sessions.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    owner: Mapped[User] = relationship(back_populates="model_assets")
    files: Mapped[list[ModelAssetFile]] = relationship(back_populates="asset")
    capture_session: Mapped[CaptureSession | None] = relationship()
