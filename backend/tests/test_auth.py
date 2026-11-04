"""Tests for AquaFix Authentication and Authorization APIs."""
import pytest
from fastapi import status

def test_register_citizen_success(client):
    """Test successful registration of a citizen user."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "newcitizen@aquafix.org",
            "password": "strongpassword123",
            "full_name": "Alice Citizen",
            "role": "citizen"
        }
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["email"] == "newcitizen@aquafix.org"
    assert data["full_name"] == "Alice Citizen"
    assert data["role"] == "citizen"
    assert "id" in data
    assert "password" not in data
    assert "hashed_password" not in data


def test_register_official_success(client):
    """Test successful registration of a municipality official."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "cityofficial@aquafix.org",
            "password": "officialpassword123",
            "full_name": "Mayor Agent",
            "role": "official"
        }
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["email"] == "cityofficial@aquafix.org"
    assert data["role"] == "official"


def test_register_duplicate_email(client, citizen_user):
    """Test registration fails with duplicate email."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": citizen_user.email,
            "password": "anotherpassword123",
            "full_name": "Clone User",
            "role": "citizen"
        }
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "already registered" in response.json()["detail"].lower()


def test_register_invalid_role(client):
    """Test registration rejects unauthorized / unknown roles."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "superadmin@aquafix.org",
            "password": "password123",
            "full_name": "Hacker",
            "role": "superadmin"
        }
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Invalid role" in response.json()["detail"]


def test_register_short_password(client):
    """Test registration validates minimum password length."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "shortpass@aquafix.org",
            "password": "123",
            "full_name": "Short Pass User",
            "role": "citizen"
        }
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "at least 6 characters" in response.json()["detail"]


def test_register_invalid_email(client):
    """Test registration fails schema validation for invalid email syntax."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "not-an-email",
            "password": "validpassword123",
            "full_name": "Bad Email User",
            "role": "citizen"
        }
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_login_success(client, citizen_user):
    """Test login with valid credentials returns JWT bearer access token."""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": citizen_user.email,
            "password": "citizenpass123"
        }
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert len(data["access_token"]) > 20


def test_login_incorrect_password(client, citizen_user):
    """Test login with incorrect password returns 401."""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": citizen_user.email,
            "password": "wrongpassword"
        }
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Invalid email or password" in response.json()["detail"]


def test_login_nonexistent_user(client):
    """Test login with unknown user returns 401."""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "ghost@doesnotexist.com",
            "password": "randompassword"
        }
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Invalid email or password" in response.json()["detail"]


def test_get_current_user_profile_authorized(client, citizen_user, citizen_headers):
    """Test GET /api/v1/auth/me returns current user profile with valid token."""
    response = client.get("/api/v1/auth/me", headers=citizen_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == citizen_user.email
    assert data["full_name"] == citizen_user.full_name
    assert data["role"] == citizen_user.role


def test_get_current_user_unauthorized(client):
    """Test GET /api/v1/auth/me rejects requests without token."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)


def test_refresh_token_authorized(client, citizen_headers):
    """Test POST /api/v1/auth/refresh returns a fresh access token."""
    response = client.post("/api/v1/auth/refresh", headers=citizen_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_refresh_token_unauthorized(client):
    """Test POST /api/v1/auth/refresh fails without valid authorization."""
    response = client.post("/api/v1/auth/refresh")
    assert response.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)


def test_update_device_token(client, citizen_headers):
    """Test POST /api/v1/auth/device-token stores device FCM token for notifications."""
    response = client.post(
        "/api/v1/auth/device-token",
        headers=citizen_headers,
        json={"fcm_token": "mock-fcm-device-token-12345"}
    )
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["fcm_token"] == "mock-fcm-device-token-12345"

    # Verify user profile now includes fcm_token
    profile_resp = client.get("/api/v1/auth/me", headers=citizen_headers)
    assert profile_resp.status_code == status.HTTP_200_OK
    assert profile_resp.json()["fcm_token"] == "mock-fcm-device-token-12345"
