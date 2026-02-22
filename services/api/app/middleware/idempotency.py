import hashlib
import uuid

from fastapi import HTTPException, Response
from sqlalchemy.orm import Session

from app.repositories.idempotency_repo import IdempotencyRepo


class IdempotencyChecker:
    def __init__(self, db: Session) -> None:
        self.repo = IdempotencyRepo(db)

    def check(
        self,
        actor_id: uuid.UUID,
        method: str,
        path: str,
        key: str,
        request_body: str,
    ) -> Response | None:
        """Check for existing idempotency key. Returns cached response if found."""
        existing = self.repo.find(actor_id=actor_id, method=method, path=path, key=key)
        if not existing:
            return None

        # Verify request hash matches
        request_hash = hashlib.sha256(request_body.encode()).hexdigest()
        if existing.request_hash and existing.request_hash != request_hash:
            raise HTTPException(
                status_code=409,
                detail="Idempotency key reused with different request body",
            )

        # Return cached response
        return Response(
            content=existing.response_body,
            status_code=existing.response_status,
            media_type="application/json",
        )

    def store(
        self,
        actor_id: uuid.UUID,
        method: str,
        path: str,
        key: str,
        request_body: str,
        response_status: int,
        response_body: str,
    ) -> None:
        """Store the response for an idempotency key."""
        request_hash = hashlib.sha256(request_body.encode()).hexdigest()
        self.repo.create(
            actor_id=actor_id,
            method=method,
            path=path,
            key=key,
            request_hash=request_hash,
            response_status=response_status,
            response_body=response_body,
        )
