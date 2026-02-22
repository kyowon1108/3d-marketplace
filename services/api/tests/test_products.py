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


def test_list_products(client, auth_headers):
    _publish_product(client, auth_headers, "Product A", 1000)
    _publish_product(client, auth_headers, "Product B", 2000)

    resp = client.get("/v1/products")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert len(data["products"]) == 2


def test_get_product(client, auth_headers):
    product = _publish_product(client, auth_headers, "Detail Test", 5000)

    resp = client.get(f"/v1/products/{product['id']}")
    assert resp.status_code == 200
    assert resp.json()["title"] == "Detail Test"


def test_get_product_404(client):
    resp = client.get(f"/v1/products/{uuid.uuid4()}")
    assert resp.status_code == 404


def test_search_products(client, auth_headers):
    _publish_product(client, auth_headers, "Blue Widget", 1000)
    _publish_product(client, auth_headers, "Red Gadget", 2000)

    resp = client.get("/v1/products?q=widget")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["products"][0]["title"] == "Blue Widget"
