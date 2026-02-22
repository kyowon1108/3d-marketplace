import hashlib
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

from app.config import settings


class StorageService:
    """Local file-based storage for development. Production would use S3."""

    def __init__(self) -> None:
        self.base_path = Path(settings.storage_local_path)
        self.base_path.mkdir(parents=True, exist_ok=True)

    def generate_storage_key(self, asset_id: uuid.UUID, role: str) -> str:
        ext_map = {
            "MODEL_USDZ": "usdz",
            "MODEL_GLB": "glb",
            "PREVIEW_PNG": "png",
        }
        ext = ext_map.get(role, "bin")
        return f"assets/{asset_id}/{role.lower()}.{ext}"

    def generate_presigned_url(self, storage_key: str) -> tuple[str, datetime]:
        """For local dev, return a file:// URL. Production would use S3 presigned URL."""
        url = f"http://localhost:8000/storage/{storage_key}"
        expires_at = datetime.now(UTC) + timedelta(hours=1)
        return url, expires_at

    def get_download_url(self, storage_key: str) -> str:
        return f"http://localhost:8000/storage/{storage_key}"

    def verify_object(
        self, storage_key: str, expected_size: int, expected_checksum: str
    ) -> bool:
        """Verify a stored object's size and SHA256 checksum."""
        file_path = self.base_path / storage_key
        if not file_path.exists():
            return False

        actual_size = file_path.stat().st_size
        if actual_size != expected_size:
            return False

        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        actual_checksum = sha256.hexdigest()

        return actual_checksum == expected_checksum

    def object_exists(self, storage_key: str) -> bool:
        return (self.base_path / storage_key).exists()

    def save_file(self, storage_key: str, data: bytes) -> None:
        """Save file locally (for dev upload simulation)."""
        file_path = self.base_path / storage_key
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(data)

    def get_object_size(self, storage_key: str) -> int | None:
        file_path = self.base_path / storage_key
        if not file_path.exists():
            return None
        return file_path.stat().st_size

    def get_object_checksum(self, storage_key: str) -> str | None:
        file_path = self.base_path / storage_key
        if not file_path.exists():
            return None
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        return sha256.hexdigest()
