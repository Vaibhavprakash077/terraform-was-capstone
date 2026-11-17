from app import app


def test_root_returns_json():
    response = app.test_client().get("/")

    assert response.status_code == 200
    assert response.is_json
    assert response.get_json() == {"message": "Hello from the Flask capstone"}


def test_health_returns_200_without_redirect_or_authentication():
    response = app.test_client().get("/health", follow_redirects=False)

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}
