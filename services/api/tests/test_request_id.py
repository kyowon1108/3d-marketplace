def test_request_id_header_returned(client):
    resp = client.get("/healthz")
    assert "x-request-id" in resp.headers


def test_request_id_propagated(client):
    resp = client.get("/healthz", headers={"X-Request-ID": "test-abc"})
    assert resp.headers["x-request-id"] == "test-abc"
