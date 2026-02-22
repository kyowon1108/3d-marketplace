import uuid

from sqlalchemy.orm import Session

from app.models.enums import ArAvailability, AssetStatus, FileRole
from app.repositories.model_asset_repo import ModelAssetRepo
from app.schemas.asset import ArAssetFileInfo, ArAssetResponse
from app.services.storage_service import StorageService


def _compute_availability(status: AssetStatus, has_model_file: bool) -> ArAvailability:
    if status in (AssetStatus.READY, AssetStatus.PUBLISHED) and has_model_file:
        return ArAvailability.READY
    if status in (AssetStatus.INITIATED, AssetStatus.UPLOADING):
        return ArAvailability.PROCESSING
    return ArAvailability.NONE


def _dims_trust(dims_source: str | None) -> str | None:
    if dims_source == "ios_lidar":
        return "high"
    if dims_source == "ios_manual":
        return "medium"
    if dims_source == "unknown":
        return "low"
    return None


class ArAssetService:
    def __init__(self, db: Session) -> None:
        self.repo = ModelAssetRepo(db)
        self.storage = StorageService()

    def get_ar_asset(self, asset_id: uuid.UUID) -> ArAssetResponse:
        asset = self.repo.get_by_id(asset_id)
        if not asset:
            return ArAssetResponse(availability=ArAvailability.NONE.value, files=[])

        files = self.repo.get_files(asset_id)
        model_roles = {FileRole.MODEL_USDZ, FileRole.MODEL_GLB}
        has_model = any(FileRole(f.file_role) in model_roles for f in files)

        availability = _compute_availability(AssetStatus(asset.status), has_model)

        ar_files: list[ArAssetFileInfo] = []
        if availability == ArAvailability.READY:
            for f in files:
                url = self.storage.get_download_url(f.storage_key)
                file_type = "preview" if FileRole(f.file_role) == FileRole.PREVIEW_PNG else "model"
                ar_files.append(
                    ArAssetFileInfo(role=f.file_role, url=url, type=file_type)
                )

        return ArAssetResponse(
            availability=availability.value,
            asset_id=asset.id,
            files=ar_files,
            dims_source=asset.dims_source,
            dims_trust=_dims_trust(asset.dims_source),
        )
