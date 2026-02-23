from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.middleware.auth import get_current_user
from app.models.enums import ImageType
from app.models.user import User
from app.repositories.purchase_repo import PurchaseRepo
from app.schemas.auth import (
    AuthProvidersResponse,
    AuthTokenResponse,
    GoogleTokenRequest,
    LogoutRequest,
    TokenRefreshRequest,
    TokenRefreshResponse,
    UserResponse,
    UserSummaryResponse,
)
from app.schemas.product import ProductResponse, PurchaseListResponse, PurchaseResponse
from app.services.auth_service import AuthService
from app.services.storage_service import StorageService

router = APIRouter(tags=["auth"])


@router.get("/v1/auth/providers", response_model=AuthProvidersResponse)
def get_auth_providers(db: Session = Depends(get_db)) -> AuthProvidersResponse:
    svc = AuthService(db)
    return svc.get_providers()


@router.get("/v1/auth/oauth/{provider}/callback", response_model=AuthTokenResponse)
def oauth_callback(
    provider: str,
    request: Request,
    code: str = Query(...),
    state: str | None = None,
    db: Session = Depends(get_db),
) -> AuthTokenResponse:
    svc = AuthService(db)

    if provider == "dev":
        if not settings.dev_auth_enabled:
            raise HTTPException(status_code=404, detail="Dev auth is not enabled")
        parts = code.split(":", 1)
        if len(parts) != 2:
            raise HTTPException(status_code=400, detail="Dev code must be email:name")
        email, name = parts
        return svc.dev_login(email=email, name=name)

    if provider == "google":
        # Web flow: exchange auth code for tokens
        redirect_uri = str(request.url_for("oauth_callback", provider="google"))
        return svc.google_login_with_code(code=code, redirect_uri=redirect_uri)

    raise HTTPException(status_code=400, detail=f"Unsupported provider: {provider}")


@router.post("/v1/auth/oauth/{provider}/token", response_model=AuthTokenResponse)
def oauth_token_exchange(
    provider: str,
    body: GoogleTokenRequest,
    db: Session = Depends(get_db),
) -> AuthTokenResponse:
    """Mobile token exchange: iOS sends a Google id_token directly."""
    if provider != "google":
        raise HTTPException(status_code=400, detail=f"Unsupported provider: {provider}")

    if not body.id_token:
        raise HTTPException(status_code=400, detail="id_token is required for mobile flow")

    svc = AuthService(db)
    return svc.google_login_with_id_token(body.id_token)


@router.post("/v1/auth/token/refresh", response_model=TokenRefreshResponse)
def refresh_token(
    body: TokenRefreshRequest,
    db: Session = Depends(get_db),
) -> TokenRefreshResponse:
    svc = AuthService(db)
    return svc.refresh_tokens(body.refresh_token)


@router.post("/v1/auth/logout", status_code=204)
def logout(
    body: LogoutRequest,
    db: Session = Depends(get_db),
) -> Response:
    svc = AuthService(db)
    svc.logout(body.refresh_token)
    return Response(status_code=204)


@router.get("/v1/auth/me", response_model=UserResponse)
def get_current_user_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserResponse:
    svc = AuthService(db)
    result = svc.get_user_response(user.id)
    if not result:
        raise HTTPException(status_code=401, detail="User not found")
    return result


@router.get("/v1/me/summary", response_model=UserSummaryResponse)
def get_user_summary(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserSummaryResponse:
    svc = AuthService(db)
    result = svc.get_user_summary(user.id)
    if not result:
        raise HTTPException(status_code=401, detail="User not found")
    return result


_storage = StorageService()


@router.get("/v1/me/purchases", response_model=PurchaseListResponse)
def get_my_purchases(
    page: int = 1,
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PurchaseListResponse:
    repo = PurchaseRepo(db)
    purchases, total = repo.list_by_buyer(user.id, page=page, limit=limit)

    items: list[PurchaseResponse] = []
    for p in purchases:
        product_resp = None
        if p.product:
            thumbnail_url = None
            if p.product.asset and p.product.asset.images:
                for img in sorted(p.product.asset.images, key=lambda i: i.sort_order):
                    if img.image_type == ImageType.THUMBNAIL:
                        thumbnail_url = _storage.get_download_url(img.storage_key)
                        break

            product_resp = ProductResponse(
                id=p.product.id,
                asset_id=p.product.asset_id,
                title=p.product.title,
                description=p.product.description,
                price_cents=p.product.price_cents,
                seller_id=p.product.seller_id,
                published_at=p.product.published_at,
                created_at=p.product.created_at,
                seller_name=p.product.seller.name if p.product.seller else "",
                thumbnail_url=thumbnail_url,
                status=p.product.status,
                likes_count=p.product.likes_count,
                views_count=p.product.views_count,
            )

        items.append(PurchaseResponse(
            id=p.id,
            product_id=p.product_id,
            buyer_id=p.buyer_id,
            price_cents=p.price_cents,
            purchased_at=p.purchased_at,
            product=product_resp,
        ))

    return PurchaseListResponse(
        purchases=items,
        total=total,
        page=page,
        limit=limit,
    )
