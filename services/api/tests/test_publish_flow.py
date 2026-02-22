import hashlib
import uuid

from app.services.storage_service import StorageService


def _create_ready_asset(client, auth_headers):
    """Helper: create an asset and complete upload to READY state."""
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    storage = StorageService()
    file_data = b"hello"
    storage_key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(storage_key, file_data)
    checksum = hashlib.sha256(file_data).hexdigest()

    client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": f"complete-{asset_id}"},
        json={
            "asset_id": asset_id,
            "files": [{"role": "MODEL_USDZ", "size_bytes": 5, "checksum_sha256": checksum}],
        },
    )
    return asset_id


def test_publish_success(client, auth_headers):
    asset_id = _create_ready_asset(client, auth_headers)

    resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": "pub-1"},
        json={
            "asset_id": asset_id,
            "title": "Test Product",
            "description": "A test",
            "price_cents": 9900,
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Test Product"
    assert data["price_cents"] == 9900
    assert data["asset_id"] == asset_id
    # New fields
    assert data["seller_name"] == "Test User"
    assert data["likes_count"] == 0
    assert data["views_count"] == 0


def test_publish_non_ready_asset(client, auth_headers):
    # Init but don't complete
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": "pub-2"},
        json={"asset_id": asset_id, "title": "Bad", "price_cents": 100},
    )
    assert resp.status_code == 400


def test_publish_idempotency_replay(client, auth_headers):
    asset_id = _create_ready_asset(client, auth_headers)

    body = {
        "asset_id": asset_id,
        "title": "Test Product",
        "price_cents": 9900,
    }

    resp1 = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": "pub-replay"},
        json=body,
    )
    assert resp1.status_code == 201

    resp2 = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": "pub-replay"},
        json=body,
    )
    assert resp2.status_code == 201
    assert resp2.json()["id"] == resp1.json()["id"]
