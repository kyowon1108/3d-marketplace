import hashlib
import uuid

from app.services.storage_service import StorageService


def _publish_product(client, auth_headers, title="Test", price=1000):
    resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={"files": [{"role": "MODEL_USDZ", "size_bytes": 5}]},
    )
    asset_id = resp.json()["asset_id"]

    storage = StorageService()
    file_data = b"hello"
    key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(key, file_data)
    checksum = hashlib.sha256(file_data).hexdigest()

    client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": f"c-{asset_id}"},
        json={
            "asset_id": asset_id,
            "files": [{"role": "MODEL_USDZ", "size_bytes": 5, "checksum_sha256": checksum}],
        },
    )

    resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": f"p-{asset_id}"},
        json={"asset_id": asset_id, "title": title, "price_cents": price},
    )
    return resp.json()


def test_like_toggle(client, auth_headers, db):
    product = _publish_product(client, auth_headers)
    product_id = product["id"]

    # Like
    resp = client.post(f"/v1/products/{product_id}/like", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["liked"] is True
    assert data["likes_count"] == 1

    # Unlike
    resp = client.post(f"/v1/products/{product_id}/like", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["liked"] is False
    assert data["likes_count"] == 0


def test_like_reflected_in_product_detail(client, auth_headers, db):
    product = _publish_product(client, auth_headers)
    product_id = product["id"]

    # Like
    client.post(f"/v1/products/{product_id}/like", headers=auth_headers)

    # Check detail
    resp = client.get(f"/v1/products/{product_id}", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["is_liked"] is True
    assert data["likes_count"] == 1


def test_like_requires_auth(client, db, auth_headers):
    product = _publish_product(client, auth_headers)
    product_id = product["id"]

    resp = client.post(f"/v1/products/{product_id}/like")
    assert resp.status_code == 401


def test_like_product_not_found(client, auth_headers):
    resp = client.post(f"/v1/products/{uuid.uuid4()}/like", headers=auth_headers)
    assert resp.status_code == 404


def test_views_increment(client, auth_headers, db):
    product = _publish_product(client, auth_headers)
    product_id = product["id"]

    # GET 4 times
    for _ in range(4):
        client.get(f"/v1/products/{product_id}")

    resp = client.get(f"/v1/products/{product_id}")
    assert resp.status_code == 200
    # 4 previous GETs + this one = 5
    assert resp.json()["views_count"] == 5
