import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.asset_image import AssetImage
from app.models.enums import ImageType


class AssetImageRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def add_image(
        self,
        asset_id: uuid.UUID,
        image_type: ImageType,
        storage_key: str,
        size_bytes: int,
        checksum_sha256: str,
        sort_order: int = 0,
    ) -> AssetImage:
        img = AssetImage(
            asset_id=asset_id,
            image_type=image_type,
            storage_key=storage_key,
            size_bytes=size_bytes,
            checksum_sha256=checksum_sha256,
            sort_order=sort_order,
        )
        self.db.add(img)
        self.db.flush()
        return img

    def get_by_asset(self, asset_id: uuid.UUID) -> list[AssetImage]:
        stmt = (
            select(AssetImage)
            .where(AssetImage.asset_id == asset_id)
            .order_by(AssetImage.sort_order)
        )
        return list(self.db.execute(stmt).scalars().all())

    def get_thumbnail(self, asset_id: uuid.UUID) -> AssetImage | None:
        stmt = (
            select(AssetImage)
            .where(AssetImage.asset_id == asset_id, AssetImage.image_type == ImageType.THUMBNAIL)
            .order_by(AssetImage.sort_order)
            .limit(1)
        )
        return self.db.execute(stmt).scalar_one_or_none()
