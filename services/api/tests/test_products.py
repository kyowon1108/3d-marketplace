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
    # New fields present with defaults
    p = data["products"][0]
    assert "seller_name" in p
    assert "likes_count" in p
    assert "views_count" in p
    assert p["likes_count"] == 0
    assert p["views_count"] == 0
    assert p["status"] == "FOR_SALE"
    assert p["chat_count"] == 0
    assert "seller_location_name" in p


def test_list_products_with_seller_name(client, auth_headers):
    _publish_product(client, auth_headers, "Product C", 3000)

    resp = client.get("/v1/products")
    assert resp.status_code == 200
    p = resp.json()["products"][0]
    assert p["seller_name"] == "Test User"


def test_list_products_no_auth(client, auth_headers):
    _publish_product(client, auth_headers, "Product D", 4000)

    # No auth header
    resp = client.get("/v1/products")
    assert resp.status_code == 200
    p = resp.json()["products"][0]
    assert p["is_liked"] is None


def test_get_product(client, auth_headers):
    product = _publish_product(client, auth_headers, "Detail Test", 5000)

    resp = client.get(f"/v1/products/{product['id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Detail Test"
    assert data["seller_name"] == "Test User"
    assert "likes_count" in data
    assert "views_count" in data
    assert data["status"] == "FOR_SALE"
    assert data["chat_count"] == 0
    assert "seller_location_name" in data


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
