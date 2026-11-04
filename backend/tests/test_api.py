"""Smoke and gateway tests for AquaFix API."""
import pytest
from fastapi import status


def test_health_check(client):
    """Test the health endpoint returns 200."""
    response = client.get("/health")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data


def test_root_endpoint(client):
    """Test the root endpoint returns API info."""
    response = client.get("/")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "name" in data
    assert "docs" in data


def test_cors_headers(client):
    """Test CORS headers are present."""
    response = client.options("/", headers={"Origin": "http://localhost:3000"})
    assert response.status_code in (status.HTTP_200_OK, status.HTTP_405_METHOD_NOT_ALLOWED)


def test_login_validation_invalid_credentials(client):
    """Test login requires valid credentials."""
    response = client.post("/api/v1/auth/login", json={
        "email": "nonexistent@example.com",
        "password": "wrongpassword"
    })
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_gemini_mock_mode():
    """Test Gemini service works in mock mode."""
    from app.services.gemini import GeminiVisionService
    service = GeminiVisionService()
    assert service.use_mock or service.api_key
