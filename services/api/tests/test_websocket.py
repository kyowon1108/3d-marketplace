import hashlib
import json
import uuid

import pytest
from sqlalchemy.orm import Session
from starlette.testclient import TestClient

from app.models.user import User
from app.services.storage_service import StorageService


def _publish_product(client: TestClient, auth_headers: dict[str, str]) -> str:
    """Create a READY asset, then publish it. Returns product_id."""
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

    resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": f"pub-{asset_id}"},
        json={"asset_id": asset_id, "title": "WS Test Product", "price_cents": 100},
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
def chat_room(
    client: TestClient,
    test_user: User,
    buyer: User,
    auth_headers: dict[str, str],
) -> dict:
    """Create product + chat room. Returns room/user IDs and tokens."""
    product_id = _publish_product(client, auth_headers)

    buyer_headers = {"Authorization": f"Bearer {buyer.id}"}
    resp = client.post(
        f"/v1/products/{product_id}/chat-rooms",
        headers=buyer_headers,
        json={"subject": "WS test chat"},
    )
    assert resp.status_code == 201
    room = resp.json()

    return {
        "room_id": room["id"],
        "seller_id": str(test_user.id),
        "buyer_id": str(buyer.id),
        "seller_token": str(test_user.id),
        "buyer_token": str(buyer.id),
    }


def test_ws_auth_missing_token(client: TestClient, chat_room: dict) -> None:
    room_id = chat_room["room_id"]
    with pytest.raises(Exception):
        with client.websocket_connect(f"/v1/chats/{room_id}"):
            pass


def test_ws_auth_invalid_token(client: TestClient, chat_room: dict) -> None:
    room_id = chat_room["room_id"]
    with pytest.raises(Exception):
        with client.websocket_connect(f"/v1/chats/{room_id}?token=bogus-invalid"):
            pass


def test_ws_not_participant(client: TestClient, db: Session, chat_room: dict) -> None:
    outsider = User(email="outsider@example.com", name="Outsider", provider="dev")
    db.add(outsider)
    db.commit()
    db.refresh(outsider)

    room_id = chat_room["room_id"]
    with pytest.raises(Exception):
        with client.websocket_connect(f"/v1/chats/{room_id}?token={outsider.id}"):
            pass


def test_ws_message_persistence(client: TestClient, chat_room: dict) -> None:
    room_id = chat_room["room_id"]
    token = chat_room["buyer_token"]
    buyer_headers = {"Authorization": f"Bearer {token}"}

    with client.websocket_connect(f"/v1/chats/{room_id}?token={token}") as ws:
        ws.send_text(json.dumps({"body": "Hello from buyer"}))
        data = ws.receive_json()
        assert data["type"] == "message"
        assert data["body"] == "Hello from buyer"
        assert data["sender_id"] == chat_room["buyer_id"]
        assert data["room_id"] == room_id

    # Verify persisted via REST API
    resp = client.get(f"/v1/chat-rooms/{room_id}/messages", headers=buyer_headers)
    assert resp.status_code == 200
    messages = resp.json()["messages"]
    assert len(messages) >= 1
    assert messages[0]["body"] == "Hello from buyer"


def test_ws_broadcast_two_clients(client: TestClient, chat_room: dict) -> None:
    room_id = chat_room["room_id"]
    seller_token = chat_room["seller_token"]
    buyer_token = chat_room["buyer_token"]

    with client.websocket_connect(f"/v1/chats/{room_id}?token={seller_token}") as ws_seller:
        with client.websocket_connect(f"/v1/chats/{room_id}?token={buyer_token}") as ws_buyer:
            # Seller sends a message
            ws_seller.send_text(json.dumps({"body": "Hello buyer!"}))

            # Seller should receive their own message (broadcast to all)
            seller_data = ws_seller.receive_json()
            assert seller_data["body"] == "Hello buyer!"

            # Buyer should also receive the broadcast
            buyer_data = ws_buyer.receive_json()
            assert buyer_data["body"] == "Hello buyer!"
            assert buyer_data["sender_id"] == chat_room["seller_id"]


def test_ws_disconnect_cleanup(client: TestClient, chat_room: dict) -> None:
    room_id = chat_room["room_id"]
    token = chat_room["buyer_token"]

    with client.websocket_connect(f"/v1/chats/{room_id}?token={token}") as ws:
        ws.send_text(json.dumps({"body": "Before disconnect"}))
        data = ws.receive_json()
        assert data["body"] == "Before disconnect"

    # After disconnect, no error — connection cleaned up gracefully
    # Reconnect should work fine
    with client.websocket_connect(f"/v1/chats/{room_id}?token={token}") as ws:
        ws.send_text(json.dumps({"body": "After reconnect"}))
        data = ws.receive_json()
        assert data["body"] == "After reconnect"
