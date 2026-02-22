import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.enums import AssetStatus, FileRole, ImageType
from app.repositories.asset_image_repo import AssetImageRepo
from app.repositories.model_asset_repo import ModelAssetRepo
from app.schemas.upload import (
    FileCompleteMeta,
    FileInitMeta,
    FileVerifyResult,
    ImageCompleteMeta,
    ImageInitMeta,
    ImageVerifyResult,
    PresignedImageTarget,
    PresignedUploadTarget,
    UploadCompleteResponse,
    UploadInitResponse,
)
from app.services.storage_service import StorageService

VALID_STATUS_FOR_INIT = {AssetStatus.INITIATED}
VALID_STATUS_FOR_COMPLETE = {AssetStatus.UPLOADING}


class UploadService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repo = ModelAssetRepo(db)
        self.image_repo = AssetImageRepo(db)
        self.storage = StorageService()

    def init_upload(
        self,
        owner_id: uuid.UUID,
        files: list[FileInitMeta],
        images: list[ImageInitMeta] | None = None,
        dims_source: str | None = None,
        dims_width: float | None = None,
        dims_height: float | None = None,
        dims_depth: float | None = None,
        capture_session_id: uuid.UUID | None = None,
    ) -> UploadInitResponse:
        images = images or []

        # Create asset
        asset = self.repo.create(
            owner_id=owner_id,
            dims_source=dims_source,
            dims_width=dims_width,
            dims_height=dims_height,
            dims_depth=dims_depth,
            capture_session_id=capture_session_id,
        )

        # Transition to UPLOADING
        self.repo.update_status(asset, AssetStatus.UPLOADING)

        # Generate presigned URLs for each file
        presigned_uploads: list[PresignedUploadTarget] = []
        for file_meta in files:
            storage_key = self.storage.generate_storage_key(asset.id, file_meta.role)
            url, expires_at = self.storage.generate_presigned_url(storage_key)
            presigned_uploads.append(
                PresignedUploadTarget(role=file_meta.role, url=url, expires_at=expires_at)
            )

        # Generate presigned URLs for each image
        presigned_image_uploads: list[PresignedImageTarget] = []
        for img_meta in images:
            storage_key = self.storage.generate_image_storage_key(
                asset.id, img_meta.image_type, img_meta.sort_order
            )
            url, expires_at = self.storage.generate_presigned_url(storage_key)
            presigned_image_uploads.append(
                PresignedImageTarget(
                    image_type=img_meta.image_type,
                    sort_order=img_meta.sort_order,
                    url=url,
                    expires_at=expires_at,
                )
            )

        self.db.commit()

        return UploadInitResponse(
            asset_id=asset.id,
            status=AssetStatus.UPLOADING.value,
            presigned_uploads=presigned_uploads,
            presigned_image_uploads=presigned_image_uploads,
        )

    def complete_upload(
        self,
        owner_id: uuid.UUID,
        asset_id: uuid.UUID,
        files: list[FileCompleteMeta],
        images: list[ImageCompleteMeta] | None = None,
    ) -> UploadCompleteResponse:
        images = images or []

        asset = self.repo.get_by_id(asset_id)
        if not asset:
            raise HTTPException(status_code=404, detail="Asset not found")

        if asset.owner_id != owner_id:
            raise HTTPException(status_code=403, detail="Not the owner of this asset")

        if AssetStatus(asset.status) not in VALID_STATUS_FOR_COMPLETE:
            raise HTTPException(
                status_code=409,
                detail=f"Asset status {asset.status} cannot be completed",
            )

        # Verify each file
        results: list[FileVerifyResult] = []
        for file_meta in files:
            storage_key = self.storage.generate_storage_key(asset_id, file_meta.role)

            # Verify the file in storage
            if not self.storage.object_exists(storage_key):
                raise HTTPException(
                    status_code=409,
                    detail=f"Object not found for role {file_meta.role}",
                )

            if not self.storage.verify_object(
                storage_key, file_meta.size_bytes, file_meta.checksum_sha256
            ):
                raise HTTPException(
                    status_code=409,
                    detail=f"Checksum/size mismatch for role {file_meta.role}",
                )

            # Record the file in DB
            self.repo.add_file(
                asset_id=asset_id,
                file_role=FileRole(file_meta.role),
                storage_key=storage_key,
                size_bytes=file_meta.size_bytes,
                checksum_sha256=file_meta.checksum_sha256,
            )
            results.append(FileVerifyResult(role=file_meta.role, verified=True))

        # Verify each image
        image_results: list[ImageVerifyResult] = []
        for img_meta in images:
            storage_key = self.storage.generate_image_storage_key(
                asset_id, img_meta.image_type, img_meta.sort_order
            )

            if not self.storage.object_exists(storage_key):
                raise HTTPException(
                    status_code=409,
                    detail=f"Image not found for {img_meta.image_type}_{img_meta.sort_order}",
                )

            if not self.storage.verify_object(
                storage_key, img_meta.size_bytes, img_meta.checksum_sha256
            ):
                raise HTTPException(
                    status_code=409,
                    detail=f"Image checksum/size mismatch for "
                    f"{img_meta.image_type}_{img_meta.sort_order}",
                )

            # Record the image in DB
            self.image_repo.add_image(
                asset_id=asset_id,
                image_type=ImageType(img_meta.image_type),
                storage_key=storage_key,
                size_bytes=img_meta.size_bytes,
                checksum_sha256=img_meta.checksum_sha256,
                sort_order=img_meta.sort_order,
            )
            image_results.append(
                ImageVerifyResult(
                    image_type=img_meta.image_type,
                    sort_order=img_meta.sort_order,
                    verified=True,
                )
            )

        # Transition to READY
        self.repo.update_status(asset, AssetStatus.READY)
        self.db.commit()

        return UploadCompleteResponse(
            asset_id=asset_id,
            status=AssetStatus.READY.value,
            files=results,
            image_results=image_results,
        )
