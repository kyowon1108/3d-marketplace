import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.enums import AssetStatus
from app.repositories.asset_image_repo import AssetImageRepo
from app.repositories.model_asset_repo import ModelAssetRepo
from app.repositories.product_repo import ProductRepo
from app.repositories.user_repo import UserRepo
from app.schemas.product import ProductResponse
from app.services.storage_service import StorageService


class PublishService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.asset_repo = ModelAssetRepo(db)
        self.product_repo = ProductRepo(db)
        self.user_repo = UserRepo(db)
        self.image_repo = AssetImageRepo(db)
        self.storage = StorageService()

    def publish(
        self,
        owner_id: uuid.UUID,
        asset_id: uuid.UUID,
        title: str,
        price_cents: int,
        description: str | None = None,
        category: str | None = None,
        condition: str | None = None,
        dims_comparison: str | None = None,
    ) -> ProductResponse:
        asset = self.asset_repo.get_by_id(asset_id)
        if not asset:
            raise HTTPException(status_code=404, detail="Asset not found")

        if asset.owner_id != owner_id:
            raise HTTPException(status_code=403, detail="Not the owner of this asset")

        if AssetStatus(asset.status) != AssetStatus.READY:
            raise HTTPException(
                status_code=400,
                detail=f"Asset status must be READY to publish, got {asset.status}",
            )

        # Create product
        product = self.product_repo.create(
            asset_id=asset_id,
            title=title,
            description=description,
            price_cents=price_cents,
            seller_id=owner_id,
            category=category,
            condition=condition,
            dims_comparison=dims_comparison,
        )

        # Transition asset to PUBLISHED
        self.asset_repo.update_status(asset, AssetStatus.PUBLISHED)
        self.db.commit()

        # Resolve seller info
        seller = self.user_repo.get_by_id(owner_id)
        seller_name = seller.name if seller else ""
        seller_avatar_url = seller.avatar_url if seller else None

        # Resolve thumbnail
        thumbnail = self.image_repo.get_thumbnail(asset_id)
        thumbnail_url = (
            self.storage.get_download_url(thumbnail.storage_key) if thumbnail else None
        )

        seller_location_name = seller.location_name if seller else None

        return ProductResponse(
            id=product.id,
            asset_id=product.asset_id,
            title=product.title,
            description=product.description,
            price_cents=product.price_cents,
            seller_id=product.seller_id,
            published_at=product.published_at,
            created_at=product.created_at,
            seller_name=seller_name,
            seller_avatar_url=seller_avatar_url,
            thumbnail_url=thumbnail_url,
            category=product.category,
            condition=product.condition,
            dims_comparison=product.dims_comparison,
            status=product.status,
            likes_count=0,
            views_count=0,
            chat_count=0,
            seller_location_name=seller_location_name,
        )
