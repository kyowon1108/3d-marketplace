import hashlib
import json
import uuid

import pytest
from sqlalchemy.orm import Session
from starlette.testclient import TestClient

from app.models.user import User
from app.services.storage_service import StorageService


def _publish_product(client: TestClient, auth_headers: dict[str, str]) -> str:
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
        headers={**auth_headers, "Idempotency-Key": f"c-{asset_id}"},
        json={
            "asset_id": asset_id,
            "files": [{"role": "MODEL_USDZ", "size_bytes": 5, "checksum_sha256": checksum}],
        },
    )

    resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": f"p-{asset_id}"},
        json={"asset_id": asset_id, "title": "Chat Test Product", "price_cents": 100},
    )
    return resp.json()["id"]


@pytest.fixture()
def buyer(db: Session) -> User:
    user = User(email="buyer@example.com", name="Buyer", provider="dev")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def chat_setup(
    client: TestClient,
    test_user: User,
    buyer: User,
    auth_headers: dict[str, str],
) -> dict:
    """Create product + chat room + send a message from buyer."""
    product_id = _publish_product(client, auth_headers)

    buyer_headers = {"Authorization": f"Bearer {buyer.id}"}
    resp = client.post(
        f"/v1/products/{product_id}/chat-rooms",
        headers=buyer_headers,
        json={"subject": "Read test chat"},
    )
    assert resp.status_code == 201
    room = resp.json()

    return {
        "room_id": room["id"],
        "product_id": product_id,
        "seller_id": str(test_user.id),
        "buyer_id": str(buyer.id),
        "seller_headers": auth_headers,
        "buyer_headers": buyer_headers,
    }


def test_last_message_body_populated(client: TestClient, chat_setup: dict) -> None:
    """Sending a message should populate last_message_body on the room."""
    room_id = chat_setup["room_id"]
    buyer_headers = chat_setup["buyer_headers"]

    # Send a message via REST
    client.post(
        f"/v1/chat-rooms/{room_id}/messages",
        headers=buyer_headers,
        json={"body": "Hello seller!"},
    )

    # List rooms — should show last_message_body
    resp = client.get("/v1/chat-rooms", headers=buyer_headers)
    assert resp.status_code == 200
    rooms = resp.json()["rooms"]
    assert len(rooms) >= 1

    room = next(r for r in rooms if r["id"] == room_id)
    assert room["last_message_body"] == "Hello seller!"
    assert room["last_message_at"] is not None


def test_unread_count_for_seller(client: TestClient, chat_setup: dict) -> None:
    """Seller should see unread messages from buyer."""
    room_id = chat_setup["room_id"]
    buyer_headers = chat_setup["buyer_headers"]
    seller_headers = chat_setup["seller_headers"]

    # Buyer sends 2 messages
    client.post(
        f"/v1/chat-rooms/{room_id}/messages",
        headers=buyer_headers,
        json={"body": "Message 1"},
    )
    client.post(
        f"/v1/chat-rooms/{room_id}/messages",
        headers=buyer_headers,
        json={"body": "Message 2"},
    )

    # Seller lists rooms — should see 2 unread
    resp = client.get("/v1/chat-rooms", headers=seller_headers)
    rooms = resp.json()["rooms"]
    room = next(r for r in rooms if r["id"] == room_id)
    assert room["unread_count"] == 2


def test_mark_read_resets_unread(client: TestClient, chat_setup: dict) -> None:
    """POST /read should reset unread_count to 0."""
    room_id = chat_setup["room_id"]
    buyer_headers = chat_setup["buyer_headers"]
    seller_headers = chat_setup["seller_headers"]

    # Buyer sends a message
    client.post(
        f"/v1/chat-rooms/{room_id}/messages",
        headers=buyer_headers,
        json={"body": "Unread message"},
    )

    # Seller marks read
    resp = client.post(f"/v1/chat-rooms/{room_id}/read", headers=seller_headers)
    assert resp.status_code == 200
    assert resp.json()["unread_count"] == 0

    # Verify via list rooms
    resp = client.get("/v1/chat-rooms", headers=seller_headers)
    rooms = resp.json()["rooms"]
    room = next(r for r in rooms if r["id"] == room_id)
    assert room["unread_count"] == 0


def test_mark_read_not_participant(client: TestClient, db: Session, chat_setup: dict) -> None:
    """Non-participant should get 403."""
    outsider = User(email="outsider@example.com", name="Outsider", provider="dev")
    db.add(outsider)
    db.commit()
    db.refresh(outsider)

    room_id = chat_setup["room_id"]
    resp = client.post(
        f"/v1/chat-rooms/{room_id}/read",
        headers={"Authorization": f"Bearer {outsider.id}"},
    )
    assert resp.status_code == 403


def test_mark_read_room_not_found(client: TestClient, auth_headers: dict[str, str]) -> None:
    """Non-existent room should get 404."""
    resp = client.post(
        f"/v1/chat-rooms/{uuid.uuid4()}/read",
        headers=auth_headers,
    )
    assert resp.status_code == 404


def test_ws_last_message_body(client: TestClient, chat_setup: dict) -> None:
    """WebSocket message should update last_message_body."""
    room_id = chat_setup["room_id"]
    buyer_token = chat_setup["buyer_id"]
    seller_headers = chat_setup["seller_headers"]

    with client.websocket_connect(f"/v1/chats/{room_id}?token={buyer_token}") as ws:
        ws.send_text(json.dumps({"body": "WS hello"}))
        ws.receive_json()

    # Verify last_message_body updated
    resp = client.get("/v1/chat-rooms", headers=seller_headers)
    rooms = resp.json()["rooms"]
    room = next(r for r in rooms if r["id"] == room_id)
    assert room["last_message_body"] == "WS hello"


def test_chat_count_on_product(client: TestClient, chat_setup: dict) -> None:
    """Product should reflect chat_count."""
    product_id = chat_setup["product_id"]

    resp = client.get(f"/v1/products/{product_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["chat_count"] == 1  # one room was created in chat_setup
