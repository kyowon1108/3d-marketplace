from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.middleware.auth import get_current_user
from app.models.user import User
from app.schemas.auth import (
    AuthProvidersResponse,
    AuthTokenResponse,
    UserResponse,
    UserSummaryResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(tags=["auth"])


@router.get("/v1/auth/providers", response_model=AuthProvidersResponse)
def get_auth_providers(db: Session = Depends(get_db)) -> AuthProvidersResponse:
    svc = AuthService(db)
    return svc.get_providers()


@router.get("/v1/auth/oauth/{provider}/callback", response_model=AuthTokenResponse)
def oauth_callback(
    provider: str,
    code: str = Query(...),
    state: str | None = None,
    db: Session = Depends(get_db),
) -> AuthTokenResponse:
    if provider != "dev":
        raise HTTPException(status_code=400, detail=f"Unsupported provider: {provider}")

    # Dev mode: code is "email:name" format
    parts = code.split(":", 1)
    if len(parts) != 2:
        raise HTTPException(status_code=400, detail="Dev code must be email:name")

    email, name = parts
    svc = AuthService(db)
    return svc.dev_login(email=email, name=name)


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
