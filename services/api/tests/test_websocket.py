import json

from starlette.testclient import TestClient

from app.main import app


def test_websocket_echo():
    client = TestClient(app)
    with client.websocket_connect("/v1/chats/00000000-0000-0000-0000-000000000001") as ws:
        ws.send_text(json.dumps({"body": "Hello via WS"}))
        data = ws.receive_json()
        assert data["type"] == "message"
        assert data["body"] == "Hello via WS"
        assert data["room_id"] == "00000000-0000-0000-0000-000000000001"


def test_websocket_multiple_messages():
    client = TestClient(app)
    with client.websocket_connect("/v1/chats/00000000-0000-0000-0000-000000000002") as ws:
        for i in range(3):
            ws.send_text(json.dumps({"body": f"msg-{i}"}))
            data = ws.receive_json()
            assert data["body"] == f"msg-{i}"
