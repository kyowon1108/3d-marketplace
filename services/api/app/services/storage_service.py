import hashlib
import hmac
import re
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.parse import urlencode

from app.config import settings

VALID_STORAGE_KEY_PATTERN = re.compile(r"^[A-Za-z0-9._/-]+$")


class StorageService:
    """Local file-based storage for development. Production would use S3."""

    upload_clock_skew_seconds = 60

    def __init__(self) -> None:
        self.base_path = Path(settings.storage_local_path).resolve()
        self.base_path.mkdir(parents=True, exist_ok=True)

    def validate_storage_key(self, storage_key: str) -> str:
        normalized = storage_key.strip()
        if not normalized:
            raise ValueError("Storage path is empty")
        if "\\" in normalized:
            raise ValueError("Backslash is not allowed in storage path")
        if normalized.startswith("/") or normalized.startswith("./"):
            raise ValueError("Absolute/relative root path is not allowed")
        if not VALID_STORAGE_KEY_PATTERN.fullmatch(normalized):
            raise ValueError("Storage path contains invalid characters")

        parts = normalized.split("/")
        if any(part in {"", ".", ".."} for part in parts):
            raise ValueError("Storage path contains invalid path segments")
        return normalized

    def resolve_safe_path(self, storage_key: str) -> Path:
        normalized = self.validate_storage_key(storage_key)
        candidate = (self.base_path / normalized).resolve()
        try:
            candidate.relative_to(self.base_path)
        except ValueError as exc:
            raise ValueError("Storage path escapes base directory") from exc
        return candidate

    def generate_storage_key(self, asset_id: uuid.UUID, role: str) -> str:
        ext_map = {
            "MODEL_USDZ": "usdz",
            "MODEL_GLB": "glb",
            "PREVIEW_PNG": "png",
        }
        ext = ext_map.get(role, "bin")
        return f"assets/{asset_id}/{role.lower()}.{ext}"

    def generate_image_storage_key(
        self, asset_id: uuid.UUID, image_type: str, sort_order: int
    ) -> str:
        return f"assets/{asset_id}/{image_type.lower()}_{sort_order}.png"

    def _sign_upload(self, storage_key: str, exp: int) -> str:
        canonical = f"PUT\n{storage_key}\n{exp}"
        secret = settings.storage_upload_signing_secret.encode("utf-8")
        digest = hmac.new(
            key=secret,
            msg=canonical.encode("utf-8"),
            digestmod=hashlib.sha256,
        )
        return digest.hexdigest()

    def generate_presigned_url(self, storage_key: str) -> tuple[str, datetime]:
        normalized = self.validate_storage_key(storage_key)
        expires_at = datetime.now(UTC) + timedelta(seconds=settings.storage_upload_ttl_seconds)
        exp = int(expires_at.timestamp())
        sig = self._sign_upload(normalized, exp)
        query = urlencode({"exp": str(exp), "sig": sig})
        url = f"{settings.server_base_url}/storage/{normalized}?{query}"
        return url, expires_at

    def verify_upload_signature(self, storage_key: str, exp: str | None, sig: str | None) -> bool:
        if not exp or not sig:
            return False
        try:
            exp_int = int(exp)
        except ValueError:
            return False

        now = int(datetime.now(UTC).timestamp())
        if exp_int < now - self.upload_clock_skew_seconds:
            return False

        normalized = self.validate_storage_key(storage_key)
        expected_sig = self._sign_upload(normalized, exp_int)
        return hmac.compare_digest(expected_sig, sig)

    def get_download_url(self, storage_key: str) -> str:
        normalized = self.validate_storage_key(storage_key)
        return f"{settings.server_base_url}/storage/{normalized}"

    def verify_object(
        self, storage_key: str, expected_size: int, expected_checksum: str
    ) -> bool:
        """Verify a stored object's size and SHA256 checksum."""
        file_path = self.resolve_safe_path(storage_key)
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
        return self.resolve_safe_path(storage_key).exists()

    def save_file(self, storage_key: str, data: bytes) -> None:
        """Save file locally (for dev upload simulation)."""
        file_path = self.resolve_safe_path(storage_key)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(data)

    def get_object_size(self, storage_key: str) -> int | None:
        file_path = self.resolve_safe_path(storage_key)
        if not file_path.exists():
            return None
        return file_path.stat().st_size

    def get_object_checksum(self, storage_key: str) -> str | None:
        file_path = self.resolve_safe_path(storage_key)
        if not file_path.exists():
            return None
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        return sha256.hexdigest()
