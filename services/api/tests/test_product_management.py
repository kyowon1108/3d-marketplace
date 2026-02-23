"""Tests for product update, delete, and status change endpoints."""

import hashlib
import uuid

from app.services.storage_service import StorageService


def _publish_product(client, auth_headers, title="Test Product", price=10000):
    """Helper: create a published product and return the response dict."""
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
    assert resp.status_code == 201
    return resp.json()


# ── PATCH /v1/products/{id} ──────────────────────────────────────


def test_update_product_title(client, auth_headers):
    product = _publish_product(client, auth_headers, "Original Title", 10000)
    resp = client.patch(
        f"/v1/products/{product['id']}",
        headers=auth_headers,
        json={"title": "New Title"},
    )
    assert resp.status_code == 200
    assert resp.json()["title"] == "New Title"
    assert resp.json()["price_cents"] == 10000  # unchanged


def test_update_product_price(client, auth_headers):
    product = _publish_product(client, auth_headers, "Price Test", 10000)
    resp = client.patch(
        f"/v1/products/{product['id']}",
        headers=auth_headers,
        json={"price_cents": 8000},
    )
    assert resp.status_code == 200
    assert resp.json()["price_cents"] == 8000


def test_update_product_not_owner(client, auth_headers, db):
    product = _publish_product(client, auth_headers, "Owner Test", 10000)

    from app.models.user import User
    other = User(email="other@example.com", name="Other", provider="dev")
    db.add(other)
    db.commit()
    db.refresh(other)
    other_headers = {"Authorization": f"Bearer {other.id}"}

    resp = client.patch(
        f"/v1/products/{product['id']}",
        headers=other_headers,
        json={"title": "Hacked"},
    )
    assert resp.status_code == 403


def test_update_product_sold_out_blocked(client, auth_headers):
    product = _publish_product(client, auth_headers, "Sold Test", 10000)

    # Change to SOLD_OUT first
    client.patch(
        f"/v1/products/{product['id']}/status",
        headers=auth_headers,
        json={"status": "SOLD_OUT"},
    )

    resp = client.patch(
        f"/v1/products/{product['id']}",
        headers=auth_headers,
        json={"title": "Cannot Edit"},
    )
    assert resp.status_code == 400


def test_update_product_empty_body(client, auth_headers):
    product = _publish_product(client, auth_headers, "Empty Test", 10000)
    resp = client.patch(
        f"/v1/products/{product['id']}",
        headers=auth_headers,
        json={},
    )
    assert resp.status_code == 400


# ── DELETE /v1/products/{id} ─────────────────────────────────────


def test_delete_product(client, auth_headers):
    product = _publish_product(client, auth_headers, "Delete Me", 10000)
    resp = client.delete(
        f"/v1/products/{product['id']}",
        headers=auth_headers,
    )
    assert resp.status_code == 204

    # Should not appear in list
    resp = client.get("/v1/products")
    assert resp.status_code == 200
    ids = [p["id"] for p in resp.json()["products"]]
    assert product["id"] not in ids

    # Should return 404 on direct get
    resp = client.get(f"/v1/products/{product['id']}")
    assert resp.status_code == 404


def test_delete_product_not_owner(client, auth_headers, db):
    product = _publish_product(client, auth_headers, "No Delete", 10000)

    from app.models.user import User
    other = User(email="other2@example.com", name="Other2", provider="dev")
    db.add(other)
    db.commit()
    db.refresh(other)
    other_headers = {"Authorization": f"Bearer {other.id}"}

    resp = client.delete(
        f"/v1/products/{product['id']}",
        headers=other_headers,
    )
    assert resp.status_code == 403


# ── PATCH /v1/products/{id}/status ───────────────────────────────


def test_change_status_to_reserved(client, auth_headers):
    product = _publish_product(client, auth_headers, "Reserve Test", 10000)
    resp = client.patch(
        f"/v1/products/{product['id']}/status",
        headers=auth_headers,
        json={"status": "RESERVED"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "RESERVED"


def test_change_status_round_trip(client, auth_headers):
    product = _publish_product(client, auth_headers, "Round Trip", 10000)

    # FOR_SALE -> RESERVED
    resp = client.patch(
        f"/v1/products/{product['id']}/status",
        headers=auth_headers,
        json={"status": "RESERVED"},
    )
    assert resp.json()["status"] == "RESERVED"

    # RESERVED -> SOLD_OUT
    resp = client.patch(
        f"/v1/products/{product['id']}/status",
        headers=auth_headers,
        json={"status": "SOLD_OUT"},
    )
    assert resp.json()["status"] == "SOLD_OUT"

    # SOLD_OUT -> FOR_SALE (seller can re-open)
    resp = client.patch(
        f"/v1/products/{product['id']}/status",
        headers=auth_headers,
        json={"status": "FOR_SALE"},
    )
    assert resp.json()["status"] == "FOR_SALE"


def test_change_status_invalid(client, auth_headers):
    product = _publish_product(client, auth_headers, "Invalid Status", 10000)
    resp = client.patch(
        f"/v1/products/{product['id']}/status",
        headers=auth_headers,
        json={"status": "INVALID_STATUS"},
    )
    assert resp.status_code == 400


# ── PATCH /v1/auth/me ────────────────────────────────────────────


def test_update_profile_name(client, auth_headers):
    resp = client.patch(
        "/v1/auth/me",
        headers=auth_headers,
        json={"name": "새닉네임"},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "새닉네임"


def test_update_profile_location(client, auth_headers):
    resp = client.patch(
        "/v1/auth/me",
        headers=auth_headers,
        json={"location_name": "강남구"},
    )
    assert resp.status_code == 200
    assert resp.json()["location_name"] == "강남구"


def test_update_profile_empty_body(client, auth_headers):
    resp = client.patch(
        "/v1/auth/me",
        headers=auth_headers,
        json={},
    )
    assert resp.status_code == 400
