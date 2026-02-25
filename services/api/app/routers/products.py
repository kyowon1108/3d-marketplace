import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.middleware.auth import get_current_user, get_optional_user
from app.middleware.idempotency import IdempotencyChecker
from app.models.enums import ImageType, ProductStatus
from app.models.product import Product
from app.models.purchase import Purchase
from app.models.user import User
from app.repositories.product_like_repo import ProductLikeRepo
from app.repositories.product_repo import ProductRepo
from app.repositories.purchase_repo import PurchaseRepo
from app.schemas.asset import ArAssetResponse
from app.schemas.chat import ChatRoomResponse, CreateChatRoomRequest
from app.schemas.product import (
    LikeToggleResponse,
    ProductListResponse,
    ProductResponse,
    ProductUpdateRequest,
    PublishRequest,
    PurchaseResponse,
    StatusChangeRequest,
)
from app.services.ar_asset_service import ArAssetService
from app.services.chat_service import ChatService
from app.services.like_service import LikeService
from app.services.publish_service import PublishService
from app.services.storage_service import StorageService

router = APIRouter(prefix="/v1/products", tags=["products"])

_storage = StorageService()


def _build_product_response(
    product: Product,
    liked_ids: set[uuid.UUID] | None = None,
    is_authed: bool = False,
    chat_count: int = 0,
    db: Session | None = None,
) -> ProductResponse:
    # Seller info
    seller_name = ""
    seller_avatar_url = None
    seller_location_name = None
    seller_joined_at = None
    seller_trade_count = 0

    if product.seller:
        seller_name = product.seller.name
        seller_avatar_url = product.seller.avatar_url
        seller_location_name = product.seller.location_name
        seller_joined_at = product.seller.created_at

        if db:
            from sqlalchemy import func

            trade_count = (
                db.query(func.count(Purchase.id))
                .join(Product, Purchase.product_id == Product.id)
                .filter(Product.seller_id == product.seller_id)
                .scalar()
                or 0
            )
            seller_trade_count = trade_count

    # Thumbnail URL from asset images
    thumbnail_url = None
    if product.asset and product.asset.images:
        for img in sorted(product.asset.images, key=lambda i: i.sort_order):
            if img.image_type == ImageType.THUMBNAIL:
                thumbnail_url = _storage.get_download_url(img.storage_key)
                break

    # is_liked
    is_liked: bool | None = None
    if is_authed and liked_ids is not None:
        is_liked = product.id in liked_ids

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
        status=product.status,
        likes_count=product.likes_count,
        views_count=product.views_count,
        chat_count=chat_count,
        seller_location_name=seller_location_name,
        seller_joined_at=seller_joined_at,
        seller_trade_count=seller_trade_count,
        is_liked=is_liked,
    )


@router.post("/publish", response_model=ProductResponse, status_code=201)
def publish_product(
    body: PublishRequest,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProductResponse:
    idempotency_key = request.headers.get("Idempotency-Key")
    if not idempotency_key:
        raise HTTPException(status_code=400, detail="Idempotency-Key header required")

    request_body_str = body.model_dump_json()

    checker = IdempotencyChecker(db)
    cached = checker.check(
        actor_id=user.id,
        method="POST",
        path="/v1/products/publish",
        key=idempotency_key,
        request_body=request_body_str,
    )
    if cached:
        return ProductResponse.model_validate_json(bytes(cached.body))

    svc = PublishService(db)
    result = svc.publish(
        owner_id=user.id,
        asset_id=body.asset_id,
        title=body.title,
        description=body.description,
        price_cents=body.price_cents,
    )

    result_json = result.model_dump_json()
    checker.store(
        actor_id=user.id,
        method="POST",
        path="/v1/products/publish",
        key=idempotency_key,
        request_body=request_body_str,
        response_status=201,
        response_body=result_json,
    )
    db.commit()

    return result


@router.get("", response_model=ProductListResponse)
def list_products(
    q: str | None = None,
    page: int = 1,
    limit: int = 20,
    seller_id: uuid.UUID | None = None,
    liked: bool | None = None,
    user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> ProductListResponse:
    # liked=true requires authentication
    liked_by_user_id: uuid.UUID | None = None
    if liked:
        if user is None:
            raise HTTPException(status_code=401, detail="Authentication required for liked filter")
        liked_by_user_id = user.id

    repo = ProductRepo(db)
    products, total = repo.list_products(
        q=q, page=page, limit=limit,
        seller_id=seller_id,
        liked_by_user_id=liked_by_user_id,
    )

    # Batch check liked IDs
    liked_ids: set[uuid.UUID] = set()
    is_authed = user is not None
    if user is not None:
        like_repo = ProductLikeRepo(db)
        product_ids = [p.id for p in products]
        liked_ids = like_repo.get_liked_product_ids(user.id, product_ids)

    # Batch chat counts
    product_ids_all = [p.id for p in products]
    chat_counts = repo.count_chats_batch(product_ids_all)

    return ProductListResponse(
        products=[
            _build_product_response(
                p,
                liked_ids=liked_ids,
                is_authed=is_authed,
                chat_count=chat_counts.get(p.id, 0),
                db=db,
            )
            for p in products
        ],
        total=total,
        page=page,
        limit=limit,
    )


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(
    product_id: uuid.UUID,
    user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> ProductResponse:
    repo = ProductRepo(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Increment views
    repo.increment_views(product_id)

    # Check if liked
    liked_ids: set[uuid.UUID] = set()
    is_authed = user is not None
    if user is not None:
        like_repo = ProductLikeRepo(db)
        if like_repo.find_like(product_id, user.id):
            liked_ids = {product_id}

    chat_count = repo.count_chats(product_id)

    return _build_product_response(
        product, liked_ids=liked_ids, is_authed=is_authed, chat_count=chat_count, db=db,
    )


@router.patch("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: uuid.UUID,
    body: ProductUpdateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProductResponse:
    repo = ProductRepo(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.seller_id != user.id:
        raise HTTPException(status_code=403, detail="Not the product owner")
    if product.status == ProductStatus.SOLD_OUT:
        raise HTTPException(status_code=400, detail="Cannot edit a sold-out product")

    fields = body.model_dump(exclude_unset=True)
    if not fields:
        raise HTTPException(status_code=400, detail="No fields to update")

    repo.update_fields(product_id, **fields)
    db.commit()

    product = repo.get_by_id(product_id)
    return _build_product_response(product, db=db)  # type: ignore[arg-type]


@router.delete("/{product_id}", status_code=204)
def delete_product(
    product_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    repo = ProductRepo(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.seller_id != user.id:
        raise HTTPException(status_code=403, detail="Not the product owner")

    repo.soft_delete(product_id)
    db.commit()


@router.patch("/{product_id}/status", response_model=ProductResponse)
def change_product_status(
    product_id: uuid.UUID,
    body: StatusChangeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProductResponse:
    repo = ProductRepo(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.seller_id != user.id:
        raise HTTPException(status_code=403, detail="Not the product owner")

    valid_statuses = {s.value for s in ProductStatus}
    if body.status not in valid_statuses:
        allowed = ", ".join(valid_statuses)
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {allowed}")

    repo.update_status(product_id, body.status)
    db.commit()

    product = repo.get_by_id(product_id)
    return _build_product_response(product, db=db)  # type: ignore[arg-type]


@router.post("/{product_id}/like", response_model=LikeToggleResponse)
def toggle_like(
    product_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> LikeToggleResponse:
    svc = LikeService(db)
    return svc.toggle_like(product_id=product_id, user_id=user.id)


@router.get("/{product_id}/ar-asset", response_model=ArAssetResponse)
def get_product_ar_asset(
    product_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ArAssetResponse:
    repo = ProductRepo(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if not product.asset_id:
        from app.models.enums import ArAvailability
        return ArAssetResponse(availability=ArAvailability.NONE.value, files=[])

    svc = ArAssetService(db)
    return svc.get_ar_asset(product.asset_id)


@router.post("/{product_id}/purchase", response_model=PurchaseResponse, status_code=201)
def purchase_product(
    product_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PurchaseResponse:
    # Lock the product row to prevent concurrent purchases
    product = db.execute(
        select(Product).where(Product.id == product_id).with_for_update()
    ).scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if product.seller_id == user.id:
        raise HTTPException(status_code=403, detail="Cannot purchase your own product")

    if product.status == ProductStatus.SOLD_OUT:
        raise HTTPException(status_code=400, detail="Product is already sold out")

    purchase_repo = PurchaseRepo(db)
    try:
        purchase = purchase_repo.create(
            product_id=product.id,
            buyer_id=user.id,
            price_cents=product.price_cents,
        )
        repo = ProductRepo(db)
        repo.update_status(product.id, ProductStatus.SOLD_OUT)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Product already purchased")
    db.refresh(purchase)

    product_resp = _build_product_response(product, db=db)
    return PurchaseResponse(
        id=purchase.id,
        product_id=purchase.product_id,
        buyer_id=purchase.buyer_id,
        price_cents=purchase.price_cents,
        purchased_at=purchase.purchased_at,
        product=product_resp,
    )


@router.post("/{product_id}/chat-rooms", response_model=ChatRoomResponse, status_code=201)
def create_product_chat_room(
    product_id: uuid.UUID,
    body: CreateChatRoomRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatRoomResponse:
    svc = ChatService(db)
    return svc.create_room(product_id=product_id, buyer_id=user.id, subject=body.subject)
