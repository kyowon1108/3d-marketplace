import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.idempotency_key import IdempotencyKey


class IdempotencyRepo:
    def __init__(self, db: Session) -> None:
        self.db = db

    def find(
        self,
        actor_id: uuid.UUID,
        method: str,
        path: str,
        key: str,
    ) -> IdempotencyKey | None:
        stmt = select(IdempotencyKey).where(
            IdempotencyKey.actor_id == actor_id,
            IdempotencyKey.method == method,
            IdempotencyKey.path == path,
            IdempotencyKey.key == key,
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def create(
        self,
        actor_id: uuid.UUID,
        method: str,
        path: str,
        key: str,
        request_hash: str | None,
        response_status: int,
        response_body: str,
    ) -> IdempotencyKey:
        record = IdempotencyKey(
            actor_id=actor_id,
            method=method,
            path=path,
            key=key,
            request_hash=request_hash,
            response_status=response_status,
            response_body=response_body,
        )
        self.db.add(record)
        self.db.flush()
        return record
