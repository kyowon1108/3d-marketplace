import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.enums import AssetStatus, FileRole
from app.models.model_asset import ModelAsset
from app.models.model_asset_file import ModelAssetFile


class ModelAssetRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(
        self,
        owner_id: uuid.UUID,
        dims_source: str | None = None,
        dims_width: float | None = None,
        dims_height: float | None = None,
        dims_depth: float | None = None,
        capture_session_id: uuid.UUID | None = None,
    ) -> ModelAsset:
        asset = ModelAsset(
            owner_id=owner_id,
            status=AssetStatus.INITIATED,
            dims_source=dims_source,
            dims_width=dims_width,
            dims_height=dims_height,
            dims_depth=dims_depth,
            capture_session_id=capture_session_id,
        )
        self.db.add(asset)
        self.db.flush()
        return asset

    def get_by_id(self, asset_id: uuid.UUID) -> ModelAsset | None:
        stmt = (
            select(ModelAsset)
            .options(selectinload(ModelAsset.files))
            .where(ModelAsset.id == asset_id)
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def update_status(self, asset: ModelAsset, status: AssetStatus) -> ModelAsset:
        asset.status = status  # type: ignore[assignment]
        self.db.flush()
        return asset

    def add_file(
        self,
        asset_id: uuid.UUID,
        file_role: FileRole,
        storage_key: str,
        size_bytes: int,
        checksum_sha256: str,
    ) -> ModelAssetFile:
        f = ModelAssetFile(
            asset_id=asset_id,
            file_role=file_role,
            storage_key=storage_key,
            size_bytes=size_bytes,
            checksum_sha256=checksum_sha256,
        )
        self.db.add(f)
        self.db.flush()
        return f

    def get_files(self, asset_id: uuid.UUID) -> list[ModelAssetFile]:
        stmt = select(ModelAssetFile).where(ModelAssetFile.asset_id == asset_id)
        return list(self.db.execute(stmt).scalars().all())
