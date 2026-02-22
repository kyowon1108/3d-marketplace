import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.product import Product


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
        return self.db.get(Product, product_id)

    def list_products(
        self,
        q: str | None = None,
        page: int = 1,
        limit: int = 20,
    ) -> tuple[list[Product], int]:
        stmt = select(Product).where(Product.published_at.isnot(None))
        count_stmt = select(func.count()).select_from(Product).where(
            Product.published_at.isnot(None)
        )

        if q:
            stmt = stmt.where(Product.title.ilike(f"%{q}%"))
            count_stmt = count_stmt.where(Product.title.ilike(f"%{q}%"))

        total = self.db.execute(count_stmt).scalar_one()

        stmt = stmt.order_by(Product.published_at.desc())
        stmt = stmt.offset((page - 1) * limit).limit(limit)

        products = list(self.db.execute(stmt).scalars().all())
        return products, total

    def get_by_asset_id(self, asset_id: uuid.UUID) -> Product | None:
        stmt = select(Product).where(Product.asset_id == asset_id)
        return self.db.execute(stmt).scalar_one_or_none()

    def count_by_seller(self, seller_id: uuid.UUID) -> int:
        stmt = select(func.count()).select_from(Product).where(Product.seller_id == seller_id)
        return self.db.execute(stmt).scalar_one()
