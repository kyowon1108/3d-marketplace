import uuid

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.models.model_asset import ModelAsset
from app.models.product import Product
from app.models.purchase import Purchase


class PurchaseRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(
        self,
        product_id: uuid.UUID,
        buyer_id: uuid.UUID,
        price_cents: int,
    ) -> Purchase:
        purchase = Purchase(
            product_id=product_id,
            buyer_id=buyer_id,
            price_cents=price_cents,
        )
        self.db.add(purchase)
        self.db.flush()
        return purchase

    def list_by_buyer(
        self, buyer_id: uuid.UUID, page: int = 1, limit: int = 20
    ) -> tuple[list[Purchase], int]:
        count_stmt = (
            select(func.count())
            .select_from(Purchase)
            .where(Purchase.buyer_id == buyer_id)
        )
        total = self.db.execute(count_stmt).scalar_one()

        stmt = (
            select(Purchase)
            .options(
                joinedload(Purchase.product)
                .joinedload(Product.seller),
                joinedload(Purchase.product)
                .joinedload(Product.asset)
                .selectinload(ModelAsset.images),
            )
            .where(Purchase.buyer_id == buyer_id)
            .order_by(Purchase.purchased_at.desc())
            .offset((page - 1) * limit)
            .limit(limit)
        )
        purchases = list(self.db.execute(stmt).unique().scalars().all())
        return purchases, total

    def get_by_product_and_buyer(
        self, product_id: uuid.UUID, buyer_id: uuid.UUID
    ) -> Purchase | None:
        stmt = select(Purchase).where(
            Purchase.product_id == product_id,
            Purchase.buyer_id == buyer_id,
        )
        return self.db.execute(stmt).scalar_one_or_none()
