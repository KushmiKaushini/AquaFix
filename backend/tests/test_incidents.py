"""Tests for AquaFix Incidents API, incident lifecycle, and AI assistance."""
import io
import uuid
import pytest
from fastapi import status
from app.models.incident import Incident
from app.models.audit import IncidentAuditTrail


def test_analyze_image_preview(client, dummy_image):
    """Test advisory AI analysis preview endpoint returns suggestions without saving."""
    dummy_image.seek(0)
    response = client.post(
        "/api/v1/incidents/analyze-image",
        files={"file": ("incident.png", dummy_image, "image/png")}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "is_infrastructure_issue" in data
    assert "category" in data
    assert "severity" in data
    assert "confidence" in data
    assert "reasoning" in data
    assert "visual_markers" in data


def test_report_incident_success(client, dummy_image):
    """Test successful reporting of an incident with full lifecycle fields."""
    dummy_image.seek(0)
    response = client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": "6.9271",
            "longitude": "79.8612",
            "description": "Severely damaged pipeline with active high pressure leak",
            "category": "Pipeline Leak",
            "severity": "Critical",
        },
        files={"file": ("leak.png", dummy_image, "image/png")}
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["status"] == "Pending"
    assert data["category"] == "Pipeline Leak"
    assert data["severity"] == "Critical"
    assert "latitude" in data
    assert "longitude" in data
    assert "created_at" in data
    assert "updated_at" in data
    assert "ai_analysis" in data
    assert data["description"] == "Severely damaged pipeline with active high pressure leak"


def test_report_incident_skip_ai_manual(client, dummy_image):
    """Test citizen can bypass AI analysis and submit manual report."""
    dummy_image.seek(0)
    response = client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": "6.9200",
            "longitude": "79.8500",
            "description": "Manual report without AI classification",
            "category": "Drainage Blockage",
            "severity": "High",
            "skip_ai": "true",
        },
        files={"file": ("drain.png", dummy_image, "image/png")}
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["category"] == "Drainage Blockage"
    assert data["severity"] == "High"
    assert data["ai_analysis"]["bypassed"] is True


def test_report_incident_invalid_coordinates(client, dummy_image):
    """Test report rejected if latitude or longitude out of geographic bounds."""
    dummy_image.seek(0)
    response = client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": "120.0",  # Invalid latitude (>90)
            "longitude": "79.8612",
            "description": "Invalid lat",
        },
        files={"file": ("photo.png", dummy_image, "image/png")}
    )
    assert response.status_code in (status.HTTP_400_BAD_REQUEST, status.HTTP_422_UNPROCESSABLE_ENTITY)


def test_report_incident_unsupported_file_type(client):
    """Test report rejected with 415 if unsupported file format is uploaded."""
    fake_txt = io.BytesIO(b"Hello this is not an image")
    response = client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": "6.9271",
            "longitude": "79.8612",
            "description": "Testing text upload",
        },
        files={"file": ("document.txt", fake_txt, "text/plain")}
    )
    assert response.status_code == status.HTTP_415_UNSUPPORTED_MEDIA_TYPE


def test_report_incident_empty_file(client):
    """Test report rejected with 400 if image file is empty (0 bytes)."""
    empty_file = io.BytesIO(b"")
    response = client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": "6.9271",
            "longitude": "79.8612",
        },
        files={"file": ("empty.png", empty_file, "image/png")}
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST


def test_report_incident_file_too_large(client):
    """Test report rejected with 413 if image exceeds 5MB limit."""
    large_payload = io.BytesIO(b"X" * (5 * 1024 * 1024 + 1024))
    response = client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": "6.9271",
            "longitude": "79.8612",
        },
        files={"file": ("huge.png", large_payload, "image/png")}
    )
    assert response.status_code == status.HTTP_413_REQUEST_ENTITY_TOO_LARGE


def test_list_incidents_pagination(client, db_session):
    """Test GET /api/v1/incidents returns paginated result structure."""
    # Seed 3 incidents
    for i in range(3):
        inc = Incident(
            id=uuid.uuid4(),
            status="Pending",
            category="Pipeline Leak",
            severity="Medium",
            description=f"Pagination test incident {i}",
            location="SRID=4326;POINT(79.8612 6.9271)"
        )
        db_session.add(inc)
    db_session.commit()

    response = client.get("/api/v1/incidents/?skip=0&limit=2")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "items" in data
    assert "total" in data
    assert "skip" in data
    assert "limit" in data
    assert len(data["items"]) <= 2


def test_list_incidents_status_and_severity_filters(client, db_session):
    """Test filtering incidents by status and severity."""
    resolved_inc = Incident(
        id=uuid.uuid4(),
        status="Resolved",
        category="Road Sinkhole",
        severity="Critical",
        description="Fixed sinkhole",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(resolved_inc)
    db_session.commit()

    response = client.get("/api/v1/incidents/?status_filter=Resolved&severity_filter=Critical")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["total"] >= 1
    assert all(item["status"] == "Resolved" for item in data["items"])
    assert all(item["severity"] == "Critical" for item in data["items"])


def test_list_incidents_text_search(client, db_session):
    """Test full-text search filtering on incident description and category."""
    special_inc = Incident(
        id=uuid.uuid4(),
        status="Pending",
        category="Road Sinkhole",
        severity="High",
        description="Huge crater near Central Boulevard junction",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(special_inc)
    db_session.commit()

    response = client.get("/api/v1/incidents/?q=Central+Boulevard")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["total"] >= 1
    assert any("Central Boulevard" in (item["description"] or "") for item in data["items"])


def test_list_incidents_invalid_status_filter(client):
    """Test filtering by nonexistent status returns 400 Bad Request."""
    response = client.get("/api/v1/incidents/?status_filter=NonExistentStatus")
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Invalid status" in response.json()["detail"]


def test_read_incident_authorized(client, citizen_headers, db_session):
    """Test GET /api/v1/incidents/{id} returns full incident details with resolution history."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Pending",
        category="Overflowing Sewage",
        severity="High",
        description="Drain overflow on Main St",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)

    audit = IncidentAuditTrail(
        id=uuid.uuid4(),
        incident_id=inc_id,
        new_status="Pending",
        internal_notes="Initial ingestion log"
    )
    db_session.add(audit)
    db_session.commit()

    response = client.get(f"/api/v1/incidents/{inc_id}", headers=citizen_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == str(inc_id)
    assert data["category"] == "Overflowing Sewage"
    assert data["severity"] == "High"
    assert data["status"] == "Pending"
    assert "history" in data
    assert len(data["history"]) >= 1
    assert data["history"][0]["new_status"] == "Pending"


def test_read_incident_unauthorized(client, db_session):
    """Test GET /api/v1/incidents/{id} rejects unauthenticated requests."""
    inc_id = uuid.uuid4()
    response = client.get(f"/api/v1/incidents/{inc_id}")
    assert response.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)


def test_read_incident_not_found(client, citizen_headers):
    """Test GET /api/v1/incidents/{id} returns 404 for unknown ID."""
    random_id = uuid.uuid4()
    response = client.get(f"/api/v1/incidents/{random_id}", headers=citizen_headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_update_status_official_success(client, official_headers, db_session):
    """Test official user updates status to 'In Progress', changes severity, and creates audit log."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Pending",
        category="Pipeline Leak",
        severity="Medium",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)
    db_session.commit()

    response = client.patch(
        f"/api/v1/incidents/{inc_id}/status",
        headers=official_headers,
        json={
            "status": "In Progress",
            "severity": "High",
            "internal_notes": "Emergency repair crew dispatched"
        }
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "In Progress"
    assert data["severity"] == "High"

    # Verify audit trail record was inserted
    audit = db_session.query(IncidentAuditTrail).filter(
        IncidentAuditTrail.incident_id == inc_id,
        IncidentAuditTrail.new_status == "In Progress"
    ).first()
    assert audit is not None
    assert audit.old_status == "Pending"
    assert "Emergency repair crew dispatched" in audit.internal_notes


def test_update_status_citizen_forbidden(client, citizen_headers, db_session):
    """Test non-official (citizen) user cannot update status (403 Forbidden)."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Pending",
        category="Pipeline Leak",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)
    db_session.commit()

    response = client.patch(
        f"/api/v1/incidents/{inc_id}/status",
        headers=citizen_headers,
        json={"status": "In Progress"}
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "Only officials" in response.json()["detail"]


def test_update_status_invalid_status_value(client, official_headers, db_session):
    """Test official providing illegal status transition returns 400 Bad Request."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Pending",
        category="Pipeline Leak",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)
    db_session.commit()

    response = client.patch(
        f"/api/v1/incidents/{inc_id}/status",
        headers=official_headers,
        json={"status": "ClosedPermanently"}
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Invalid status" in response.json()["detail"]


def test_get_incident_history_endpoint(client, official_headers, db_session):
    """Test GET /api/v1/incidents/{id}/history returns chronological resolution history."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Resolved",
        category="Road Sinkhole",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)

    log1 = IncidentAuditTrail(
        id=uuid.uuid4(),
        incident_id=inc_id,
        new_status="Pending",
        internal_notes="Initial report"
    )
    log2 = IncidentAuditTrail(
        id=uuid.uuid4(),
        incident_id=inc_id,
        old_status="Pending",
        new_status="Resolved",
        internal_notes="Filled and sealed"
    )
    db_session.add_all([log1, log2])
    db_session.commit()

    response = client.get(f"/api/v1/incidents/{inc_id}/history", headers=official_headers)
    assert response.status_code == status.HTTP_200_OK
    items = response.json()
    assert len(items) == 2
    assert items[0]["new_status"] == "Pending"
    assert items[1]["new_status"] == "Resolved"


def test_delete_incident_official_success(client, official_headers, db_session):
    """Test official user can delete an incident."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Pending",
        category="Pipeline Leak",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)
    db_session.commit()

    response = client.delete(f"/api/v1/incidents/{inc_id}", headers=official_headers)
    assert response.status_code == status.HTTP_200_OK

    # Verify deleted
    assert db_session.query(Incident).filter(Incident.id == inc_id).first() is None


def test_delete_incident_citizen_forbidden(client, citizen_headers, db_session):
    """Test citizen user cannot delete an incident (403 Forbidden)."""
    inc_id = uuid.uuid4()
    inc = Incident(
        id=inc_id,
        status="Pending",
        category="Pipeline Leak",
        location="SRID=4326;POINT(79.8612 6.9271)"
    )
    db_session.add(inc)
    db_session.commit()

    response = client.delete(f"/api/v1/incidents/{inc_id}", headers=citizen_headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN
