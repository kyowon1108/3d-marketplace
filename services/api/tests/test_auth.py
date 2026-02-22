def test_get_providers(client):
    resp = client.get("/v1/auth/providers")
    assert resp.status_code == 200
    assert "dev" in resp.json()["providers"]


def test_dev_login(client):
    resp = client.get("/v1/auth/oauth/dev/callback?code=test@example.com:Test+User")
    assert resp.status_code == 200
    data = resp.json()
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == "test@example.com"
    assert data["access_token"]  # non-empty


def test_get_me(client, auth_headers):
    resp = client.get("/v1/auth/me", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == "test@example.com"


def test_get_me_unauthorized(client):
    resp = client.get("/v1/auth/me")
    assert resp.status_code == 401


def test_get_summary(client, auth_headers):
    resp = client.get("/v1/me/summary", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["product_count"] == 0
    assert data["unread_messages"] == 0
