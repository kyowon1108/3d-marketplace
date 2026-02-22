"""E2E test: full seller flow from upload to chat message (11 API calls)."""

import hashlib
import json
import uuid

from sqlalchemy.orm import Session
from starlette.testclient import TestClient

from app.models.user import User
from app.services.storage_service import StorageService


def test_e2e_seller_flow(
    client: TestClient, test_user: User, db: Session, auth_headers: dict[str, str],
) -> None:
    """E2E: init → upload → complete → publish → list → get → ar → chat → msg."""

    # 1. Upload init
    init_resp = client.post(
        "/v1/model-assets/uploads/init",
        headers=auth_headers,
        json={
            "dims_source": "ios_lidar",
            "dims_width": 0.3,
            "dims_height": 0.5,
            "dims_depth": 0.2,
            "files": [{"role": "MODEL_USDZ", "size_bytes": 11}],
        },
    )
    assert init_resp.status_code == 200
    init_data = init_resp.json()
    asset_id = init_data["asset_id"]
    assert init_data["status"] == "UPLOADING"
    assert len(init_data["presigned_uploads"]) == 1

    # 2. Simulate file upload to local storage
    storage = StorageService()
    file_data = b"hello-world"
    storage_key = storage.generate_storage_key(uuid.UUID(asset_id), "MODEL_USDZ")
    storage.save_file(storage_key, file_data)
    checksum = hashlib.sha256(file_data).hexdigest()

    # 3. Upload complete
    complete_resp = client.post(
        "/v1/model-assets/uploads/complete",
        headers={**auth_headers, "Idempotency-Key": f"complete-{asset_id}"},
        json={
            "asset_id": asset_id,
            "files": [{"role": "MODEL_USDZ", "size_bytes": 11, "checksum_sha256": checksum}],
        },
    )
    assert complete_resp.status_code == 200
    assert complete_resp.json()["status"] == "READY"

    # 4. Verify asset status
    asset_resp = client.get(f"/v1/model-assets/{asset_id}", headers=auth_headers)
    assert asset_resp.status_code == 200
    assert asset_resp.json()["status"] == "READY"

    # 5. Publish product
    publish_resp = client.post(
        "/v1/products/publish",
        headers={**auth_headers, "Idempotency-Key": f"pub-{asset_id}"},
        json={
            "asset_id": asset_id,
            "title": "E2E Test Product",
            "description": "Full flow test",
            "price_cents": 4900,
        },
    )
    assert publish_resp.status_code == 201
    product = publish_resp.json()
    product_id = product["id"]
    assert product["title"] == "E2E Test Product"
    assert product["price_cents"] == 4900

    # 6. List products — should include our product
    list_resp = client.get("/v1/products", headers=auth_headers)
    assert list_resp.status_code == 200
    product_ids = [p["id"] for p in list_resp.json()["products"]]
    assert product_id in product_ids

    # 7. Get single product
    get_resp = client.get(f"/v1/products/{product_id}", headers=auth_headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["title"] == "E2E Test Product"

    # 8. Get AR asset
    ar_resp = client.get(f"/v1/products/{product_id}/ar-asset", headers=auth_headers)
    assert ar_resp.status_code == 200
    ar_data = ar_resp.json()
    assert ar_data["availability"] == "READY"
    assert ar_data["dims_source"] == "ios_lidar"
    assert ar_data["dims_trust"] == "high"

    # 9. Create chat room (as buyer)
    buyer = User(email="e2e-buyer@example.com", name="E2E Buyer", provider="dev")
    db.add(buyer)
    db.commit()
    db.refresh(buyer)
    buyer_headers = {"Authorization": f"Bearer {buyer.id}"}

    chat_resp = client.post(
        f"/v1/products/{product_id}/chat-rooms",
        headers=buyer_headers,
        json={"subject": "E2E chat test"},
    )
    assert chat_resp.status_code == 201
    room_id = chat_resp.json()["id"]

    # 10. Send message via REST
    msg_resp = client.post(
        f"/v1/chat-rooms/{room_id}/messages",
        headers=buyer_headers,
        json={"body": "Hi, is this still available?"},
    )
    assert msg_resp.status_code == 201
    assert msg_resp.json()["body"] == "Hi, is this still available?"

    # 11. Send message via WebSocket
    with client.websocket_connect(f"/v1/chats/{room_id}?token={test_user.id}") as ws:
        ws.send_text(json.dumps({"body": "Yes, it's available!"}))
        data = ws.receive_json()
        assert data["body"] == "Yes, it's available!"
        assert data["sender_id"] == str(test_user.id)

    # Verify both messages persisted
    msgs_resp = client.get(f"/v1/chat-rooms/{room_id}/messages", headers=auth_headers)
    assert msgs_resp.status_code == 200
    messages = msgs_resp.json()["messages"]
    assert len(messages) == 2
    bodies = {m["body"] for m in messages}
    assert "Hi, is this still available?" in bodies
    assert "Yes, it's available!" in bodies
