import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.repositories.product_like_repo import ProductLikeRepo
from app.repositories.product_repo import ProductRepo
from app.schemas.product import LikeToggleResponse


class LikeService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.like_repo = ProductLikeRepo(db)
        self.product_repo = ProductRepo(db)

    def toggle_like(self, product_id: uuid.UUID, user_id: uuid.UUID) -> LikeToggleResponse:
        # Verify product exists
        product = self.product_repo.get_by_id(product_id)
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        existing = self.like_repo.find_like(product_id, user_id)
        if existing:
            # Unlike
            self.like_repo.delete_like(existing)
            new_count = self.product_repo.decrement_likes(product_id)
            self.db.commit()
            return LikeToggleResponse(liked=False, likes_count=new_count)
        else:
            # Like
            self.like_repo.create_like(product_id, user_id)
            new_count = self.product_repo.increment_likes(product_id)
            self.db.commit()
            return LikeToggleResponse(liked=True, likes_count=new_count)
