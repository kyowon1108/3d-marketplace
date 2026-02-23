import hashlib
import uuid

from sqlalchemy import update

from app.models.product import Product
from app.models.user import User
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


def _create_buyer(db) -> tuple[User, dict[str, str]]:
    buyer = User(email="buyer@example.com", name="Buyer", provider="dev")
    db.add(buyer)
    db.commit()
    db.refresh(buyer)
    return buyer, {"Authorization": f"Bearer {buyer.id}"}


def test_purchase_success(client, auth_headers, test_user, db):
    product = _publish_product(client, auth_headers, "Widget", 5000)
    buyer, buyer_headers = _create_buyer(db)

    resp = client.post(f"/v1/products/{product['id']}/purchase", headers=buyer_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["product_id"] == product["id"]
    assert data["buyer_id"] == str(buyer.id)
    assert data["price_cents"] == 5000
    assert data["product"] is not None
    assert data["product"]["title"] == "Widget"

    # Verify product is now SOLD_OUT
    resp = client.get(f"/v1/products/{product['id']}")
    assert resp.json()["status"] == "SOLD_OUT"


def test_purchase_own_product_forbidden(client, auth_headers, test_user, db):
    product = _publish_product(client, auth_headers, "My Item", 1000)

    resp = client.post(f"/v1/products/{product['id']}/purchase", headers=auth_headers)
    assert resp.status_code == 403
    assert "own product" in resp.json()["detail"].lower()


def test_purchase_sold_out_product(client, auth_headers, test_user, db):
    product = _publish_product(client, auth_headers, "Gadget", 2000)
    buyer, buyer_headers = _create_buyer(db)

    # First purchase succeeds
    resp = client.post(f"/v1/products/{product['id']}/purchase", headers=buyer_headers)
    assert resp.status_code == 201

    # Second purchase fails — already sold out
    buyer2 = User(email="buyer2@example.com", name="Buyer2", provider="dev")
    db.add(buyer2)
    db.commit()
    db.refresh(buyer2)
    buyer2_headers = {"Authorization": f"Bearer {buyer2.id}"}

    resp = client.post(f"/v1/products/{product['id']}/purchase", headers=buyer2_headers)
    assert resp.status_code == 400
    assert "sold out" in resp.json()["detail"].lower()


def test_my_purchases_list(client, auth_headers, test_user, db):
    product1 = _publish_product(client, auth_headers, "Item A", 1000)
    product2 = _publish_product(client, auth_headers, "Item B", 2000)
    buyer, buyer_headers = _create_buyer(db)

    client.post(f"/v1/products/{product1['id']}/purchase", headers=buyer_headers)
    client.post(f"/v1/products/{product2['id']}/purchase", headers=buyer_headers)

    resp = client.get("/v1/me/purchases", headers=buyer_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert len(data["purchases"]) == 2
    # Most recent first
    assert data["purchases"][0]["product"]["title"] == "Item B"


def test_my_purchases_pagination(client, auth_headers, test_user, db):
    for i in range(3):
        _publish_product(client, auth_headers, f"Item {i}", 1000 * (i + 1))

    buyer, buyer_headers = _create_buyer(db)

    # Purchase all 3
    resp = client.get("/v1/products")
    for p in resp.json()["products"]:
        client.post(f"/v1/products/{p['id']}/purchase", headers=buyer_headers)

    # Page 1, limit 2
    resp = client.get("/v1/me/purchases?page=1&limit=2", headers=buyer_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert len(data["purchases"]) == 2

    # Page 2, limit 2
    resp = client.get("/v1/me/purchases?page=2&limit=2", headers=buyer_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["purchases"]) == 1


def test_purchase_not_found(client, db):
    buyer, buyer_headers = _create_buyer(db)
    resp = client.post(f"/v1/products/{uuid.uuid4()}/purchase", headers=buyer_headers)
    assert resp.status_code == 404


def test_duplicate_purchase_returns_409(client, auth_headers, test_user, db):
    """Two purchases of the same product: second must get 409 (unique constraint)."""
    product = _publish_product(client, auth_headers, "Unique Item", 3000)
    buyer, buyer_headers = _create_buyer(db)

    resp1 = client.post(f"/v1/products/{product['id']}/purchase", headers=buyer_headers)
    assert resp1.status_code == 201

    # Force product status back to FOR_SALE to bypass the status check,
    # simulating a race condition where two requests read status before either writes.
    db.execute(
        update(Product).where(Product.id == uuid.UUID(product["id"])).values(status="FOR_SALE")
    )
    db.commit()

    buyer2 = User(email="buyer3@example.com", name="Buyer3", provider="dev")
    db.add(buyer2)
    db.commit()
    db.refresh(buyer2)
    buyer2_headers = {"Authorization": f"Bearer {buyer2.id}"}

    resp2 = client.post(f"/v1/products/{product['id']}/purchase", headers=buyer2_headers)
    assert resp2.status_code == 409
    assert "already purchased" in resp2.json()["detail"].lower()
