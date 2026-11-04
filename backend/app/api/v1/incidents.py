import os
import uuid
import shutil
import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status, Request
from sqlalchemy.orm import Session
from sqlalchemy import func, cast
from typing import List, Optional
from slowapi import Limiter
from slowapi.util import get_remote_address
from geoalchemy2 import Geometry

from app.core.database import get_db
from app.core.auth import verify_token
from app.models.incident import Incident
from app.models.audit import IncidentAuditTrail
from app.models.user import User
from app.schemas.incident import (
    IncidentResponse,
    IncidentStatusUpdate,
    IncidentAuditResponse,
    AIAnalysisSuggestion,
    VALID_STATUSES,
    VALID_SEVERITIES,
    VALID_CATEGORIES,
)
from app.services.gemini import gemini_service

logger = logging.getLogger("aquafix.incidents")

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)

# Define local uploads directory
UPLOAD_DIR = os.path.join(os.getcwd(), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# File upload constraints
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def validate_uploaded_image(file: UploadFile, image_bytes: bytes):
    """Common image validation for reporting and AI preview."""
    file_extension = os.path.splitext(file.filename or "")[1].lower() if file.filename else ""
    if file_extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file extension: {file_extension}. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}"
        )
    
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported MIME type: {file.content_type}. Allowed: {', '.join(sorted(ALLOWED_MIME_TYPES))}"
        )
    
    if len(image_bytes) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size: {MAX_FILE_SIZE / (1024*1024):.1f} MB, received: {len(image_bytes) / (1024*1024):.1f} MB"
        )
    
    if len(image_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty"
        )


@router.post("/analyze-image", response_model=AIAnalysisSuggestion)
@limiter.limit("15/minute")
async def analyze_image_preview(
    request: Request,
    file: UploadFile = File(...),
):
    """
    Advisory AI analysis preview:
    Analyzes an incident photo using Google Gemini to suggest category,
    severity, confidence, reasoning, and visual markers.
    Does NOT save to the database. Citizens can review, edit, or reject suggestions.
    """
    image_bytes = await file.read()
    validate_uploaded_image(file, image_bytes)

    try:
        gemini_result = await gemini_service.verify_and_categorize_incident(
            image_bytes=image_bytes,
            mime_type=file.content_type or "image/jpeg"
        )
        return AIAnalysisSuggestion(
            is_infrastructure_issue=gemini_result.get("is_infrastructure_issue", True),
            category=gemini_result.get("category", "Public Sanitation Issue"),
            severity=gemini_result.get("severity", "Medium"),
            confidence=gemini_result.get("confidence", 0.85),
            reasoning=gemini_result.get("reasoning", "Analysis complete."),
            visual_markers=gemini_result.get("visual_markers", [])
        )
    except Exception as e:
        logger.warning(f"AI image preview analysis failed: {str(e)}")
        # Return fallback recommendation rather than failing completely
        return AIAnalysisSuggestion(
            is_infrastructure_issue=True,
            category="Public Sanitation Issue",
            severity="Medium",
            confidence=0.50,
            reasoning="AI analysis unavailable at this time. Please select category and severity manually.",
            visual_markers=["manual inspection recommended"]
        )


@router.post("/report", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
async def report_incident(
    request: Request,
    latitude: float = Form(..., ge=-90.0, le=90.0),
    longitude: float = Form(..., ge=-180.0, le=180.0),
    description: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    severity: Optional[str] = Form("Medium"),
    skip_ai: Optional[bool] = Form(False),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Ingest a citizen reported incident.
    - Supports responsible AI: Gemini output is treated as advisory suggestions.
    - Citizens can supply manual category & severity or bypass AI via skip_ai=True.
    - If AI service is unavailable or flags an issue, reports are still accepted
      and flagged for human official review.
    """
    # 1. Validate file
    image_bytes = await file.read()
    validate_uploaded_image(file, image_bytes)

    # 2. Validate coordinates
    if abs(latitude) > 90 or abs(longitude) > 180:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid geographic coordinates"
        )

    # 3. Validate description if provided
    if description and len(description.strip()) > 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Description too long (max 1000 characters)"
        )

    # Validate category & severity if manually supplied
    chosen_category = category if category in VALID_CATEGORIES else None
    chosen_severity = severity if severity in VALID_SEVERITIES else "Medium"

    ai_metadata = None
    audit_notes = "Incident reported by citizen."

    # 4. Handle AI suggestion or manual submission
    if skip_ai:
        chosen_category = chosen_category or "Public Sanitation Issue"
        ai_metadata = {"bypassed": True, "reason": "User submitted manual report without AI"}
        audit_notes = "Incident ingested with manual user verification (AI skipped by user)."
    else:
        try:
            gemini_result = await gemini_service.verify_and_categorize_incident(
                image_bytes=image_bytes,
                mime_type=file.content_type or "image/jpeg"
            )
            ai_metadata = gemini_result

            # If user didn't specify category, use AI suggestion
            if not chosen_category:
                chosen_category = gemini_result.get("category", "Public Sanitation Issue")

            # If user didn't specify non-default severity, use AI suggested severity
            if severity == "Medium" and "severity" in gemini_result:
                chosen_severity = gemini_result.get("severity", "Medium")

            if not gemini_result.get("is_infrastructure_issue", False):
                # If citizen provided explicit description or category, queue for official review
                if description or category:
                    audit_notes = (
                        f"AI advisory warning: {gemini_result.get('reasoning', 'Potential non-infrastructure issue')}. "
                        "Accepted based on citizen details; flagged for official human review."
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Spam Filter Rejection: {gemini_result.get('reasoning', 'Not a valid sanitation/infrastructure issue.')} (You can submit with manual category and description if this is a mistake.)"
                    )
            else:
                audit_notes = f"AI verified ({chosen_category}, severity: {chosen_severity}). {gemini_result.get('reasoning', '')}"
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(f"Gemini AI processing failed during report: {str(e)}")
            chosen_category = chosen_category or "Public Sanitation Issue"
            ai_metadata = {"status": "unavailable", "detail": "AI service offline during ingestion"}
            audit_notes = "Incident ingested. AI analysis service was unavailable; queued for manual review."

    # Final fallback for category & severity
    chosen_category = chosen_category or "Public Sanitation Issue"
    if chosen_category not in VALID_CATEGORIES:
        chosen_category = "Public Sanitation Issue"
    if chosen_severity not in VALID_SEVERITIES:
        chosen_severity = "Medium"

    # 5. Save file locally
    file_extension = os.path.splitext(file.filename or "")[1].lower() if file.filename else ".jpg"
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    filepath = os.path.join(UPLOAD_DIR, unique_filename)

    await file.seek(0)
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    image_url = f"/uploads/{unique_filename}"
    wkt_location = f"SRID=4326;POINT({longitude} {latitude})"

    # 6. Create SQL model
    db_incident = Incident(
        status="Pending",
        category=chosen_category,
        severity=chosen_severity,
        description=description,
        image_url=image_url,
        ai_analysis=ai_metadata,
        location=wkt_location
    )

    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)

    # 7. Add initial audit trail log
    db_audit = IncidentAuditTrail(
        incident_id=db_incident.id,
        new_status="Pending",
        internal_notes=audit_notes
    )
    db.add(db_audit)
    db.commit()

    return IncidentResponse(
        id=db_incident.id,
        status=db_incident.status,
        category=db_incident.category,
        severity=db_incident.severity,
        description=db_incident.description,
        image_url=db_incident.image_url,
        latitude=latitude,
        longitude=longitude,
        ai_analysis=db_incident.ai_analysis,
        created_at=db_incident.created_at,
        updated_at=db_incident.updated_at,
        reporter_id=db_incident.reporter_id
    )


@router.get("/", response_model=dict)
def read_incidents(
    status_filter: Optional[str] = None,
    severity_filter: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    radius: Optional[float] = None,  # in meters
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """
    Get incidents with pagination and optional filters.
    Query Parameters:
    - skip: Number of records to skip (default: 0)
    - limit: Maximum records to return (default: 20, max: 100)
    - status_filter: Filter by status (Pending, In Progress, Resolved, Rejected)
    - severity_filter: Filter by severity (Low, Medium, High, Critical)
    - lat, lon, radius: Geographic radius filter (all three required)
    """
    skip = max(0, skip)
    limit = max(1, min(100, limit))

    query = db.query(Incident)

    if status_filter:
        if status_filter not in VALID_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"
            )
        query = query.filter(Incident.status == status_filter)

    if severity_filter:
        if severity_filter not in VALID_SEVERITIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid severity. Must be one of: {', '.join(sorted(VALID_SEVERITIES))}"
            )
        query = query.filter(Incident.severity == severity_filter)

    if lat is not None and lon is not None and radius is not None:
        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid geographic coordinates"
            )
        if radius <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Radius must be greater than 0"
            )
        point = f"SRID=4326;POINT({lon} {lat})"
        query = query.filter(func.ST_DWithin(Incident.location, point, radius))

    total_count = query.count()

    incidents_with_coords = (
        db.query(
            Incident,
            func.ST_X(cast(Incident.location, Geometry)).label("longitude"),
            func.ST_Y(cast(Incident.location, Geometry)).label("latitude")
        )
        .order_by(Incident.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    results = []
    for row in incidents_with_coords:
        inc = row.Incident
        results.append(
            IncidentResponse(
                id=inc.id,
                status=inc.status,
                category=inc.category,
                severity=inc.severity,
                description=inc.description,
                image_url=inc.image_url,
                latitude=row.latitude or 0.0,
                longitude=row.longitude or 0.0,
                ai_analysis=inc.ai_analysis,
                created_at=inc.created_at,
                updated_at=inc.updated_at,
                reporter_id=inc.reporter_id
            )
        )

    return {
        "items": results,
        "total": total_count,
        "skip": skip,
        "limit": limit,
        "page": (skip // limit) + 1 if limit > 0 else 1,
        "total_pages": (total_count + limit - 1) // limit if limit > 0 else 1
    }


@router.get("/{incident_id}", response_model=IncidentResponse)
def read_incident(
    incident_id: uuid.UUID,
    token_payload: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Get a single incident by ID with coordinates and full resolution audit history.
    REQUIRES: Valid JWT token.
    """
    row = (
        db.query(
            Incident,
            func.ST_X(cast(Incident.location, Geometry)).label("longitude"),
            func.ST_Y(cast(Incident.location, Geometry)).label("latitude")
        )
        .filter(Incident.id == incident_id)
        .first()
    )

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )

    inc = row.Incident

    # Fetch resolution history
    audit_records = (
        db.query(IncidentAuditTrail)
        .filter(IncidentAuditTrail.incident_id == incident_id)
        .order_by(IncidentAuditTrail.changed_at.asc())
        .all()
    )

    history = [
        IncidentAuditResponse(
            id=a.id,
            incident_id=a.incident_id,
            modified_by=a.modified_by,
            modifier_name=a.modifier.full_name if a.modifier else "System / Reporter",
            old_status=a.old_status,
            new_status=a.new_status,
            internal_notes=a.internal_notes,
            changed_at=a.changed_at
        )
        for a in audit_records
    ]

    return IncidentResponse(
        id=inc.id,
        status=inc.status,
        category=inc.category,
        severity=inc.severity,
        description=inc.description,
        image_url=inc.image_url,
        latitude=row.latitude or 0.0,
        longitude=row.longitude or 0.0,
        ai_analysis=inc.ai_analysis,
        created_at=inc.created_at,
        updated_at=inc.updated_at,
        reporter_id=inc.reporter_id,
        history=history
    )


@router.get("/{incident_id}/history", response_model=List[IncidentAuditResponse])
def get_incident_history(
    incident_id: uuid.UUID,
    token_payload: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Get full resolution history / audit trail for an incident.
    REQUIRES: Valid JWT token.
    """
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )

    audit_records = (
        db.query(IncidentAuditTrail)
        .filter(IncidentAuditTrail.incident_id == incident_id)
        .order_by(IncidentAuditTrail.changed_at.asc())
        .all()
    )

    return [
        IncidentAuditResponse(
            id=a.id,
            incident_id=a.incident_id,
            modified_by=a.modified_by,
            modifier_name=a.modifier.full_name if a.modifier else "System / Reporter",
            old_status=a.old_status,
            new_status=a.new_status,
            internal_notes=a.internal_notes,
            changed_at=a.changed_at
        )
        for a in audit_records
    ]


@router.patch("/{incident_id}/status", response_model=IncidentResponse)
def update_incident_status(
    incident_id: uuid.UUID,
    payload: IncidentStatusUpdate,
    token_payload: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Update incident status and/or severity and append tracking record to Audit Trail.
    REQUIRES: Valid JWT token AND 'official' role.
    """
    user_id_str = token_payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token - missing user ID"
        )

    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID format in token"
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )

    if user.role != "official":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Only officials can update incident status. Your role: {user.role}"
        )

    row = (
        db.query(
            Incident,
            func.ST_X(cast(Incident.location, Geometry)).label("longitude"),
            func.ST_Y(cast(Incident.location, Geometry)).label("latitude")
        )
        .filter(Incident.id == incident_id)
        .first()
    )

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Requested Incident ID not found."
        )

    db_incident = row.Incident

    if payload.status not in VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"
        )

    if payload.severity and payload.severity not in VALID_SEVERITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid severity. Must be one of: {', '.join(sorted(VALID_SEVERITIES))}"
        )

    old_status = db_incident.status
    db_incident.status = payload.status
    if payload.severity:
        db_incident.severity = payload.severity

    db_audit = IncidentAuditTrail(
        incident_id=db_incident.id,
        modified_by=user_id,
        old_status=old_status,
        new_status=payload.status,
        internal_notes=payload.internal_notes or f"Status updated by official: {user.full_name}"
    )
    db.add(db_audit)
    db.commit()
    db.refresh(db_incident)

    return IncidentResponse(
        id=db_incident.id,
        status=db_incident.status,
        category=db_incident.category,
        severity=db_incident.severity,
        description=db_incident.description,
        image_url=db_incident.image_url,
        latitude=row.latitude or 0.0,
        longitude=row.longitude or 0.0,
        ai_analysis=db_incident.ai_analysis,
        created_at=db_incident.created_at,
        updated_at=db_incident.updated_at,
        reporter_id=db_incident.reporter_id
    )


@router.delete("/{incident_id}", status_code=status.HTTP_200_OK)
def delete_incident(
    incident_id: uuid.UUID,
    token_payload: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Delete an incident report (Official only).
    """
    user_id_str = token_payload.get("sub")
    if not user_id_str:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.role != "official":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only officials can delete incidents"
        )

    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )

    db.delete(incident)
    db.commit()

    return {"detail": f"Incident {incident_id} successfully deleted"}
