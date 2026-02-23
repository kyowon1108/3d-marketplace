import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session, joinedload

from app.models.chat import ChatRoom
from app.models.model_asset import ModelAsset
from app.models.product import Product
from app.models.product_like import ProductLike


class ProductRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(
        self,
        asset_id: uuid.UUID,
        title: str,
        price_cents: int,
        seller_id: uuid.UUID,
        description: str | None = None,
    ) -> Product:
        product = Product(
            asset_id=asset_id,
            title=title,
            description=description,
            price_cents=price_cents,
            seller_id=seller_id,
            published_at=datetime.now(UTC),
        )
        self.db.add(product)
        self.db.flush()
        return product

    def get_by_id(self, product_id: uuid.UUID) -> Product | None:
        stmt = (
            select(Product)
            .options(
                joinedload(Product.seller),
                joinedload(Product.asset).selectinload(ModelAsset.images),
            )
            .where(Product.id == product_id, Product.deleted_at.is_(None))
        )
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def list_products(
        self,
        q: str | None = None,
        page: int = 1,
        limit: int = 20,
        seller_id: uuid.UUID | None = None,
        liked_by_user_id: uuid.UUID | None = None,
    ) -> tuple[list[Product], int]:
        stmt = (
            select(Product)
            .options(
                joinedload(Product.seller),
                joinedload(Product.asset).selectinload(ModelAsset.images),
            )
            .where(Product.published_at.isnot(None), Product.deleted_at.is_(None))
        )
        count_stmt = select(func.count()).select_from(Product).where(
            Product.published_at.isnot(None), Product.deleted_at.is_(None)
        )

        if q:
            stmt = stmt.where(Product.title.ilike(f"%{q}%"))
            count_stmt = count_stmt.where(Product.title.ilike(f"%{q}%"))

        if seller_id is not None:
            stmt = stmt.where(Product.seller_id == seller_id)
            count_stmt = count_stmt.where(Product.seller_id == seller_id)

        if liked_by_user_id is not None:
            liked_subq = (
                select(ProductLike.product_id)
                .where(ProductLike.user_id == liked_by_user_id)
                .subquery()
            )
            stmt = stmt.where(Product.id.in_(select(liked_subq)))
            count_stmt = count_stmt.where(Product.id.in_(select(liked_subq)))

        total = self.db.execute(count_stmt).scalar_one()

        stmt = stmt.order_by(Product.published_at.desc())
        stmt = stmt.offset((page - 1) * limit).limit(limit)

        products = list(self.db.execute(stmt).unique().scalars().all())
        return products, total

    def count_chats(self, product_id: uuid.UUID) -> int:
        stmt = (
            select(func.count())
            .select_from(ChatRoom)
            .where(ChatRoom.product_id == product_id)
        )
        return self.db.execute(stmt).scalar_one()

    def count_chats_batch(self, product_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
        if not product_ids:
            return {}
        stmt = (
            select(ChatRoom.product_id, func.count())
            .where(ChatRoom.product_id.in_(product_ids))
            .group_by(ChatRoom.product_id)
        )
        rows = self.db.execute(stmt).all()
        return {row[0]: row[1] for row in rows}

    def get_by_asset_id(self, asset_id: uuid.UUID) -> Product | None:
        stmt = select(Product).where(Product.asset_id == asset_id)
        return self.db.execute(stmt).scalar_one_or_none()

    def count_by_seller(self, seller_id: uuid.UUID) -> int:
        stmt = select(func.count()).select_from(Product).where(Product.seller_id == seller_id)
        return self.db.execute(stmt).scalar_one()

    def increment_views(self, product_id: uuid.UUID) -> None:
        stmt = (
            update(Product)
            .where(Product.id == product_id)
            .values(views_count=Product.views_count + 1)
        )
        self.db.execute(stmt)
        self.db.flush()

    def increment_likes(self, product_id: uuid.UUID) -> int:
        stmt = (
            update(Product)
            .where(Product.id == product_id)
            .values(likes_count=Product.likes_count + 1)
            .returning(Product.likes_count)
        )
        result = self.db.execute(stmt).scalar_one()
        self.db.flush()
        return result

    def update_status(self, product_id: uuid.UUID, status: str) -> None:
        stmt = (
            update(Product)
            .where(Product.id == product_id)
            .values(status=status)
        )
        self.db.execute(stmt)
        self.db.flush()

    def decrement_likes(self, product_id: uuid.UUID) -> int:
        stmt = (
            update(Product)
            .where(Product.id == product_id)
            .values(likes_count=func.greatest(Product.likes_count - 1, 0))
            .returning(Product.likes_count)
        )
        result = self.db.execute(stmt).scalar_one()
        self.db.flush()
        return result

    def update_fields(self, product_id: uuid.UUID, **fields: Any) -> None:
        stmt = (
            update(Product)
            .where(Product.id == product_id)
            .values(**fields)
        )
        self.db.execute(stmt)
        self.db.flush()

    def soft_delete(self, product_id: uuid.UUID) -> None:
        stmt = (
            update(Product)
            .where(Product.id == product_id)
            .values(deleted_at=datetime.now(UTC))
        )
        self.db.execute(stmt)
        self.db.flush()
