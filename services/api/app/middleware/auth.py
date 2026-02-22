import uuid

import jwt
from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.services.jwt_service import JwtService


def resolve_user_from_token(token: str, db: Session) -> User | None:
    """Try JWT first, then UUID fallback in dev/test mode."""
    # 1. Try JWT decode
    try:
        jwt_service = JwtService()
        payload = jwt_service.decode_access_token(token)
        user_id = uuid.UUID(str(payload["sub"]))
        return db.get(User, user_id)
    except (jwt.InvalidTokenError, KeyError, ValueError):
        pass

    # 2. UUID fallback (dev/test only)
    if settings.app_env in ("local", "test"):
        try:
            user_id = uuid.UUID(token)
            return db.get(User, user_id)
        except ValueError:
            pass

    return None


def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    """Extract and validate the current user from the Authorization header.

    Supports JWT access tokens. In local/test env, also accepts raw UUID.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

    token = auth_header.removeprefix("Bearer ").strip()

    user = resolve_user_from_token(token, db)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token or user not found")

    return user


def get_optional_user(request: Request, db: Session = Depends(get_db)) -> User | None:
    """Return the current user if a valid Bearer token is present, else None.

    Never raises 401 — used for endpoints that work with or without auth.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    token = auth_header.removeprefix("Bearer ").strip()

    return resolve_user_from_token(token, db)
