import uuid

from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User


def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    """Extract and validate the current user from the Authorization header.

    Dev mode: Bearer token is the user's UUID.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

    token = auth_header.removeprefix("Bearer ").strip()

    try:
        user_id = uuid.UUID(token)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid token format")

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user
