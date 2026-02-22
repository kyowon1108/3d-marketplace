import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.middleware.auth import get_current_user
from app.middleware.idempotency import IdempotencyChecker
from app.models.user import User
from app.repositories.product_repo import ProductRepo
from app.schemas.asset import ArAssetResponse
from app.schemas.chat import ChatRoomResponse, CreateChatRoomRequest
from app.schemas.product import ProductListResponse, ProductResponse, PublishRequest
from app.services.ar_asset_service import ArAssetService
from app.services.chat_service import ChatService
from app.services.publish_service import PublishService

router = APIRouter(prefix="/v1/products", tags=["products"])


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
    db: Session = Depends(get_db),
) -> ProductListResponse:
    repo = ProductRepo(db)
    products, total = repo.list_products(q=q, page=page, limit=limit)
    return ProductListResponse(
        products=[
            ProductResponse(
                id=p.id,
                asset_id=p.asset_id,
                title=p.title,
                description=p.description,
                price_cents=p.price_cents,
                seller_id=p.seller_id,
                published_at=p.published_at,
                created_at=p.created_at,
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
    db: Session = Depends(get_db),
) -> ProductResponse:
    repo = ProductRepo(db)
    product = repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return ProductResponse(
        id=product.id,
        asset_id=product.asset_id,
        title=product.title,
        description=product.description,
        price_cents=product.price_cents,
        seller_id=product.seller_id,
        published_at=product.published_at,
        created_at=product.created_at,
    )


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


@router.post("/{product_id}/chat-rooms", response_model=ChatRoomResponse, status_code=201)
def create_product_chat_room(
    product_id: uuid.UUID,
    body: CreateChatRoomRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatRoomResponse:
    svc = ChatService(db)
    return svc.create_room(product_id=product_id, buyer_id=user.id, subject=body.subject)
