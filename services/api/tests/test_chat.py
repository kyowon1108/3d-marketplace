import hashlib
import uuid

from app.services.storage_service import StorageService


def _create_product(client, auth_headers):
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
        json={"asset_id": asset_id, "title": "Chat Product", "price_cents": 1000},
    )
    return resp.json()["id"]


def test_create_chat_room(client, auth_headers):
    product_id = _create_product(client, auth_headers)

    resp = client.post(
        f"/v1/products/{product_id}/chat-rooms",
        headers=auth_headers,
        json={"subject": "Is this available?"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["subject"] == "Is this available?"
    assert data["product_id"] == product_id


def test_list_chat_rooms(client, auth_headers):
    product_id = _create_product(client, auth_headers)

    client.post(
        f"/v1/products/{product_id}/chat-rooms",
        headers=auth_headers,
        json={"subject": "Room 1"},
    )

    resp = client.get("/v1/chat-rooms", headers=auth_headers)
    assert resp.status_code == 200
    assert len(resp.json()["rooms"]) >= 1


def test_send_and_get_messages(client, auth_headers):
    product_id = _create_product(client, auth_headers)

    resp = client.post(
        f"/v1/products/{product_id}/chat-rooms",
        headers=auth_headers,
        json={"subject": "Msg test"},
    )
    room_id = resp.json()["id"]

    # Send message
    resp = client.post(
        f"/v1/chat-rooms/{room_id}/messages",
        headers=auth_headers,
        json={"body": "Hello!"},
    )
    assert resp.status_code == 201
    assert resp.json()["body"] == "Hello!"

    # Get messages
    resp = client.get(f"/v1/chat-rooms/{room_id}/messages", headers=auth_headers)
    assert resp.status_code == 200
    assert len(resp.json()["messages"]) == 1
