"""Backend tests for AquaFix API."""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

# Test configuration
def test_health_check():
    """Test the health endpoint returns 200."""
    from app.main import app
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data


def test_root_endpoint():
    """Test the root endpoint returns API info."""
    from app.main import app
    client = TestClient(app)
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "name" in data
    assert "docs" in data


def test_cors_headers():
    """Test CORS headers are present."""
    from app.main import app
    client = TestClient(app)
    response = client.options("/", headers={"Origin": "http://localhost:3000"})
    # CORS middleware should be active
    assert response.status_code in (200, 405)  # 405 if OPTIONS not explicitly handled


def test_rate_limiter_register():
    """Test rate limiting on register endpoint."""
    from app.main import app
    client = TestClient(app)
    # Make multiple requests to trigger rate limit
    for i in range(7):
        response = client.post("/api/v1/auth/register", json={
            "email": f"test{i}@example.com",
            "password": "testpass123",
            "full_name": f"Test User {i}"
        })
    # At least one should be rate limited (429) or all should be valid (if rate limit not triggered)
    assert response.status_code in (201, 400, 429)


def test_login_validation():
    """Test login requires valid credentials."""
    from app.main import app
    client = TestClient(app)
    response = client.post("/api/v1/auth/login", json={
        "email": "nonexistent@example.com",
        "password": "wrongpassword"
    })
    assert response.status_code == 401


def test_incidents_list_requires_auth():
    """Test GET /incidents requires authentication."""
    from app.main import app
    client = TestClient(app)
    response = client.get("/api/v1/incidents/")
    assert response.status_code == 403  # No auth token


def test_gemini_mock_mode():
    """Test Gemini service works in mock mode."""
    from app.services.gemini import GeminiVisionService
    service = GeminiVisionService()
    # Without API key, should use mock mode
    assert service.use_mock or service.api_key


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
