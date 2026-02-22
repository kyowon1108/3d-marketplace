
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.middleware.auth import get_current_user
from app.middleware.idempotency import IdempotencyChecker
from app.models.user import User
from app.schemas.upload import (
    UploadCompleteRequest,
    UploadCompleteResponse,
    UploadInitRequest,
    UploadInitResponse,
)
from app.services.upload_service import UploadService

router = APIRouter(prefix="/v1/model-assets/uploads", tags=["uploads"])


@router.post("/init", response_model=UploadInitResponse)
def init_upload(
    body: UploadInitRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UploadInitResponse:
    svc = UploadService(db)
    return svc.init_upload(
        owner_id=user.id,
        files=body.files,
        dims_source=body.dims_source,
        dims_width=body.dims_width,
        dims_height=body.dims_height,
        dims_depth=body.dims_depth,
        capture_session_id=body.capture_session_id,
    )


@router.post("/complete", response_model=UploadCompleteResponse)
def complete_upload(
    body: UploadCompleteRequest,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UploadCompleteResponse:
    idempotency_key = request.headers.get("Idempotency-Key")
    if not idempotency_key:
        raise HTTPException(status_code=400, detail="Idempotency-Key header required")

    request_body_str = body.model_dump_json()

    # Check idempotency
    checker = IdempotencyChecker(db)
    cached = checker.check(
        actor_id=user.id,
        method="POST",
        path="/v1/model-assets/uploads/complete",
        key=idempotency_key,
        request_body=request_body_str,
    )
    if cached:
        return UploadCompleteResponse.model_validate_json(bytes(cached.body))

    svc = UploadService(db)
    result = svc.complete_upload(
        owner_id=user.id, asset_id=body.asset_id, files=body.files
    )

    # Store idempotency
    result_json = result.model_dump_json()
    checker.store(
        actor_id=user.id,
        method="POST",
        path="/v1/model-assets/uploads/complete",
        key=idempotency_key,
        request_body=request_body_str,
        response_status=200,
        response_body=result_json,
    )
    db.commit()

    return result
