import hashlib
import uuid

from app.services.storage_service import StorageService


def test_ar_asset_ready(client, auth_headers):
    # Create READY asset → publish → get ar-asset
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"dims_source": "ios_lidar", "files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    storage = StorageService()
    file_data = b"hello"
    storage_key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(storage_key, file_data)
    checksum = hashlib.sha256(file_data).hexdigest()

    client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": f"c-{asset_id}"},
        json={
            "asset_id": asset_id,
            "files": [{"role": "MODEL_USDZ", "size_bytes": 5, "checksum_sha256": checksum}],
        },
    )

    # Publish
    resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": f"p-{asset_id}"},
        json={"asset_id": asset_id, "title": "AR Product", "price_cents": 5000},
    )
    product_id = resp.json()["id"]

    # Get ar-asset
    resp = client.get(f"/v1/products/{product_id}/ar-asset", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["availability"] == "READY"
    assert data["dims_source"] == "ios_lidar"
    assert data["dims_trust"] == "high"
    assert len(data["files"]) == 1
    assert data["files"][0]["type"] == "model"


def test_ar_asset_none_no_asset(client, auth_headers):
    # Product with no asset
    resp = client.get(f"/v1/products/{uuid.uuid4()}/ar-asset", headers=auth_headers)
    assert resp.status_code == 404


def test_model_asset_status(client, auth_headers):
    # Create and check status
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    resp = client.get(f"/v1/model-assets/{asset_id}", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "UPLOADING"
    assert data["availability"] == "PROCESSING"
