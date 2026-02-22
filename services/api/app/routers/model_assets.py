import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.middleware.auth import get_current_user
from app.models.enums import AssetStatus, FileRole
from app.models.user import User
from app.repositories.model_asset_repo import ModelAssetRepo
from app.schemas.asset import AssetFileInfo, AssetImageInfo, ModelAssetResponse
from app.services.ar_asset_service import _compute_availability

router = APIRouter(prefix="/v1/model-assets", tags=["model-assets"])


@router.get("/{asset_id}", response_model=ModelAssetResponse)
def get_model_asset(
    asset_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ModelAssetResponse:
    repo = ModelAssetRepo(db)
    asset = repo.get_by_id(asset_id)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")

    files = asset.files
    model_roles = {FileRole.MODEL_USDZ, FileRole.MODEL_GLB}
    has_model = any(FileRole(f.file_role) in model_roles for f in files)
    availability = _compute_availability(AssetStatus(asset.status), has_model)

    return ModelAssetResponse(
        id=asset.id,
        owner_id=asset.owner_id,
        status=asset.status,
        availability=availability.value,
        dims_source=asset.dims_source,
        dims_width=asset.dims_width,
        dims_height=asset.dims_height,
        dims_depth=asset.dims_depth,
        files=[
            AssetFileInfo(
                role=f.file_role,
                storage_key=f.storage_key,
                size_bytes=f.size_bytes,
                checksum_sha256=f.checksum_sha256,
            )
            for f in files
        ],
        images=[
            AssetImageInfo(
                id=img.id,
                image_type=img.image_type,
                storage_key=img.storage_key,
                size_bytes=img.size_bytes,
                sort_order=img.sort_order,
            )
            for img in asset.images
        ],
        created_at=asset.created_at,
        updated_at=asset.updated_at,
    )
