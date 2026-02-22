import hashlib
import uuid

from app.services.storage_service import StorageService


def test_init_upload(client, auth_headers):
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={
            "dims_source": "ios_lidar",
            "files": [
                {"role": "MODEL_USDZ", "size_bytes": 1024},
                {"role": "PREVIEW_PNG", "size_bytes": 512},
            ],
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "UPLOADING"
    assert len(data["presigned_uploads"]) == 2
    assert data["presigned_uploads"][0]["role"] == "MODEL_USDZ"


def test_init_upload_unauthorized(client):
    resp = client.post(
        "/v1/model-assets/uploads/init",
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 1024}]},
    )
    assert resp.status_code == 401


def test_complete_upload_success(client, auth_headers, test_user):
    # 1. Init
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    # 2. Simulate file upload to local storage
    storage = StorageService()
    file_data = b"hello"
    storage_key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(storage_key, file_data)

    checksum = hashlib.sha256(file_data).hexdigest()

    # 3. Complete
    resp = client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": "test-key-1"},
        json={
            "asset_id": asset_id,
            "files": [
                {
                    "role": "MODEL_USDZ",
                    "size_bytes": 5,
                    "checksum_sha256": checksum,
                }
            ],
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "READY"
    assert data["files"][0]["verified"] is True


def test_complete_upload_checksum_mismatch(client, auth_headers):
    # Init
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    # Upload file
    storage = StorageService()
    storage_key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(storage_key, b"hello")

    # Complete with wrong checksum
    resp = client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": "test-key-2"},
        json={
            "asset_id": asset_id,
            "files": [
                {
                    "role": "MODEL_USDZ",
                    "size_bytes": 5,
                    "checksum_sha256": "0" * 64,
                }
            ],
        },
    )
    assert resp.status_code == 409


def test_complete_upload_missing_object(client, auth_headers):
    # Init
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    # Complete without uploading
    resp = client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": "test-key-3"},
        json={
            "asset_id": asset_id,
            "files": [
                {
                    "role": "MODEL_USDZ",
                    "size_bytes": 5,
                    "checksum_sha256": "abc123",
                }
            ],
        },
    )
    assert resp.status_code == 409


def test_complete_upload_idempotency_replay(client, auth_headers):
    # Init
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    # Upload
    storage = StorageService()
    file_data = b"hello"
    storage_key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(storage_key, file_data)
    checksum = hashlib.sha256(file_data).hexdigest()

    body = {
        "asset_id": asset_id,
        "files": [{"role": "MODEL_USDZ", "size_bytes": 5, "checksum_sha256": checksum}],
    }

    # First complete
    resp1 = client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": "test-key-replay"},
        json=body,
    )
    assert resp1.status_code == 200

    # Replay — same key, same body
    resp2 = client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": "test-key-replay"},
        json=body,
    )
    assert resp2.status_code == 200
    assert resp2.json()["asset_id"] == asset_id
    assert resp2.json()["status"] == "READY"


def test_complete_upload_no_idempotency_key(client, auth_headers):
    resp = client.post(
        "/v1/model-assets/uploads/complete",
        headers=auth_headers,
        json={"asset_id": str(uuid.uuid4()), "files": []},
    )
    assert resp.status_code == 400
