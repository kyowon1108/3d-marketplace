import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.product_like import ProductLike


class ProductLikeRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def find_like(self, product_id: uuid.UUID, user_id: uuid.UUID) -> ProductLike | None:
        stmt = select(ProductLike).where(
            ProductLike.product_id == product_id,
            ProductLike.user_id == user_id,
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def create_like(self, product_id: uuid.UUID, user_id: uuid.UUID) -> ProductLike:
        like = ProductLike(product_id=product_id, user_id=user_id)
        self.db.add(like)
        self.db.flush()
        return like

    def delete_like(self, like: ProductLike) -> None:
        self.db.delete(like)
        self.db.flush()

    def get_liked_product_ids(
        self, user_id: uuid.UUID, product_ids: list[uuid.UUID]
    ) -> set[uuid.UUID]:
        if not product_ids:
            return set()
        stmt = select(ProductLike.product_id).where(
            ProductLike.user_id == user_id,
            ProductLike.product_id.in_(product_ids),
        )
        return set(self.db.execute(stmt).scalars().all())
