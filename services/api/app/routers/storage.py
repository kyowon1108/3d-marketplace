from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

from app.config import settings
from app.services.storage_service import StorageService

router = APIRouter(tags=["storage"])


@router.put("/storage/{path:path}")
async def upload_file(path: str, request: Request) -> dict[str, str]:
    """Local dev endpoint: receive file upload (simulates S3 presigned PUT)."""
    if settings.app_env == "production":
        raise HTTPException(status_code=404)

    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail="Empty body")

    storage = StorageService()
    storage.save_file(path, body)
    return {"status": "ok"}


@router.get("/storage/{path:path}")
def download_file(path: str) -> Response:
    """Local dev endpoint: serve stored files (simulates S3/CDN download)."""
    if settings.app_env == "production":
        raise HTTPException(status_code=404)

    storage = StorageService()
    file_path = storage.base_path / path
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
