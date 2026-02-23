from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import Response

from app.config import settings
from app.services.storage_service import StorageService

router = APIRouter(tags=["storage"])


def _ensure_local_storage() -> None:
    if settings.app_env != "local":
        raise HTTPException(status_code=404)


@router.put("/storage/{path:path}")
async def upload_file(
    path: str,
    request: Request,
    exp: str | None = Query(default=None),
    sig: str | None = Query(default=None),
) -> dict[str, str]:
    """Local dev endpoint: receive file upload (simulates S3 presigned PUT)."""
    _ensure_local_storage()

    storage = StorageService()
    try:
        storage.resolve_safe_path(path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    if not storage.verify_upload_signature(path, exp=exp, sig=sig):
        raise HTTPException(status_code=403, detail="Invalid or expired upload signature")

    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail="Empty body")

    storage.save_file(path, body)
    return {"status": "ok"}


@router.get("/storage/{path:path}")
def download_file(path: str) -> Response:
    """Local dev endpoint: serve stored files (simulates S3/CDN download)."""
    _ensure_local_storage()

    storage = StorageService()
    try:
        file_path = storage.resolve_safe_path(path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    suffix = file_path.suffix.lower()
    media_types = {
        ".usdz": "model/vnd.usdz+zip",
        ".glb": "model/gltf-binary",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
    }
    media_type = media_types.get(suffix, "application/octet-stream")

    return Response(content=file_path.read_bytes(), media_type=media_type)
