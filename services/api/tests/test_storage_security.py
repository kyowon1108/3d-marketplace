import hashlib
import hmac
import time
from urllib.parse import urlencode, urlparse

from app.config import settings
from app.services.storage_service import StorageService


def _build_signature(storage_key: str, exp: int) -> str:
    canonical = f"PUT\n{storage_key}\n{exp}"
    return hmac.new(
        settings.storage_upload_signing_secret.encode("utf-8"),
        canonical.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def test_storage_put_requires_signature(client, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "local")
    resp = client.put("/storage/assets/test/missing-sig.bin", content=b"abc")
    assert resp.status_code == 403


def test_storage_put_rejects_traversal_path(client, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "local")
    storage = StorageService()
    signed_url, _ = storage.generate_presigned_url("assets/x/valid.bin")
    query = urlparse(signed_url).query

    resp = client.put(f"/storage/assets/../evil.bin?{query}", content=b"abc")
    assert resp.status_code in {400, 403}


def test_storage_put_rejects_expired_signature(client, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "local")
    storage_key = "assets/test/expired.bin"
    expired_exp = int(time.time()) - 3600
    sig = _build_signature(storage_key, expired_exp)
    query = urlencode({"exp": str(expired_exp), "sig": sig})

    resp = client.put(f"/storage/{storage_key}?{query}", content=b"abc")
    assert resp.status_code == 403


def test_storage_put_accepts_valid_signature(client, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "local")
    storage = StorageService()
    storage_key = "assets/test/ok.bin"
    signed_url, _ = storage.generate_presigned_url(storage_key)
    parsed = urlparse(signed_url)

    resp = client.put(f"{parsed.path}?{parsed.query}", content=b"hello")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
    assert storage.object_exists(storage_key)


def test_storage_endpoints_blocked_in_non_local(client, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "beta")

    get_resp = client.get("/storage/assets/test/non-local.bin")
    assert get_resp.status_code == 404

    put_resp = client.put("/storage/assets/test/non-local.bin", content=b"abc")
    assert put_resp.status_code == 404
