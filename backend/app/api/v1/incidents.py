import os
import uuid
import shutil
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status, Request
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.core.database import get_db
from app.core.auth import verify_token
from app.core.config import settings
from app.models.incident import Incident
from app.models.audit import IncidentAuditTrail
from app.schemas.incident import IncidentResponse, IncidentStatusUpdate
from app.services.gemini import gemini_service

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)

# Define local uploads directory
UPLOAD_DIR = os.path.join(os.getcwd(), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# File upload constraints
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

@router.post("/report", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
async def report_incident(
    request: Request,
    latitude: float = Form(..., ge=-90.0, le=90.0),
    longitude: float = Form(..., ge=-180.0, le=180.0),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Ingest a citizen reported incident.
    Saves image, runs Gemini Vision validation, performs PostGIS insertion.
    
    Constraints:
    - File size max: 5 MB
    - Allowed types: JPEG, PNG, WebP
    """
    # 1. Validate file extension
    file_extension = os.path.splitext(file.filename or "")[1].lower() if file.filename else ""
    if file_extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file extension: {file_extension}. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # 2. Validate MIME type
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported MIME type: {file.content_type}. Allowed: {', '.join(ALLOWED_MIME_TYPES)}"
        )
    
    # 3. Read image bytes and validate size
    image_bytes = await file.read()
    
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
    
    # 4. Validate coordinates are reasonable
    if abs(latitude) > 90 or abs(longitude) > 180:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid geographic coordinates"
        )
    
    # 5. Validate description if provided
    if description and len(description.strip()) > 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Description too long (max 1000 characters)"
        )
    
    # 6. Call Gemini Vision API
    try:
        gemini_result = await gemini_service.verify_and_categorize_incident(
            image_bytes=image_bytes, 
            mime_type=file.content_type or "image/jpeg"
        )
    except ValueError as ve:
        # Validation error from Gemini response
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image analysis failed: {str(ve)}"
        )
    except Exception as e:
        # Gemini API or other critical errors
        import logging
        logging.error(f"Gemini service error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI image analysis service temporarily unavailable. Please try again later."
        )
    
    # 7. Spam filtering checks
    if not gemini_result.get("is_infrastructure_issue", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Spam Filter Rejection: {gemini_result.get('reasoning', 'Not a valid sanitation/infrastructure issue.')}"
        )

    # 8. Save file locally for verification
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    filepath = os.path.join(UPLOAD_DIR, unique_filename)
    
    # Reset stream pointer and save
    await file.seek(0)
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Define local accessible asset URL
    image_url = f"/uploads/{unique_filename}"
    
    # 9. Build spatial coordinate string for PostGIS Point mapping
    # Note: PostGIS POINT parameters take Longitude first, then Latitude
    wkt_location = f"SRID=4326;POINT({longitude} {latitude})"
    
    # 10. Create SQL model
    db_incident = Incident(
        status="Pending",
        category=gemini_result.get("category", "Public Sanitation Issue"),
        description=description or gemini_result.get("reasoning", ""),
        image_url=image_url,
        location=wkt_location
    )
    
    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)
    
    # 11. Add initial audit trail log
    db_audit = IncidentAuditTrail(
        incident_id=db_incident.id,
        new_status="Pending",
        internal_notes="Incident ingested and automatically verified by Google Gemini 1.5 Flash Vision API."
    )
    db.add(db_audit)
    db.commit()
    
    # 12. Transform db representation to coordinate outputs for Pydantic mapping
    return IncidentResponse(
        id=db_incident.id,
        status=db_incident.status,
        category=db_incident.category,
        description=db_incident.description,
        image_url=db_incident.image_url,
        latitude=latitude,
        longitude=longitude,
        created_at=db_incident.created_at,
        updated_at=db_incident.updated_at
    )

@router.get("/", response_model=dict)  # Using dict to include pagination
def read_incidents(
    status_filter: Optional[str] = None,
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
    - lat, lon, radius: Geographic radius filter (all three required)
    
    Returns: {items: [...], total: int, skip: int, limit: int, page: int, total_pages: int}
    """
    from app.schemas.incident import PaginatedIncidentResponse
    
    # Validate pagination parameters
    skip = max(0, skip)
    limit = max(1, min(100, limit))  # Clamp between 1-100
    
    query = db.query(Incident)
    
    # Apply status filter if provided
    if status_filter:
        from app.schemas.incident import VALID_STATUSES
        if status_filter not in VALID_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid status. Must be one of: {', '.join(VALID_STATUSES)}"
            )
        query = query.filter(Incident.status == status_filter)
    
    # Implement PostGIS radial query if lat, lon, and radius are supplied
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
        # ST_DWithin handles spatial geography distance checking
        query = query.filter(func.ST_DWithin(Incident.location, point, radius))
    
    # Get total count before pagination
    total_count = query.count()

    # Apply pagination — single query with coordinate extraction in SELECT
    # Fixes N+1: instead of calling db.scalar(ST_X/ST_Y) per row, we extract
    # coordinates directly in the SQL query using func.ST_X/func.ST_Y
    # Geography type must be cast to geometry before ST_X/ST_Y
    incidents_with_coords = (
        db.query(
            Incident,
            func.ST_X(Incident.location.cast(func.geometry)).label("longitude"),
            func.ST_Y(Incident.location.cast(func.geometry)).label("latitude")
        )
        .order_by(Incident.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    # Build response from query results
    results = []
    for row in incidents_with_coords:
        inc = row.Incident
        results.append(
            IncidentResponse(
                id=inc.id,
                status=inc.status,
                category=inc.category,
                description=inc.description,
                image_url=inc.image_url,
                latitude=row.latitude,
                longitude=row.longitude,
                created_at=inc.created_at,
                updated_at=inc.updated_at
            )
        )

    # Return paginated response
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
    Get a single incident by ID.
    REQUIRES: Valid JWT token.
    """
    db_incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not db_incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )

    # Extract coordinates
    try:
        lon_coord = db.scalar(func.ST_X(db_incident.location.cast(func.geometry)))
        lat_coord = db.scalar(func.ST_Y(db_incident.location.cast(func.geometry)))
    except Exception as e:
        import logging
        logging.error(f"Failed to extract coordinates for incident {db_incident.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to extract incident location coordinates"
        )

    return IncidentResponse(
        id=db_incident.id,
        status=db_incident.status,
        category=db_incident.category,
        description=db_incident.description,
        image_url=db_incident.image_url,
        latitude=lat_coord,
        longitude=lon_coord,
        created_at=db_incident.created_at,
        updated_at=db_incident.updated_at
    )


@router.patch("/{incident_id}/status", response_model=IncidentResponse)
def update_incident_status(
    incident_id: uuid.UUID,
    payload: IncidentStatusUpdate,
    token_payload: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Update incident status and append tracking record to Audit Trail.
    REQUIRES: Valid JWT token AND 'official' role.
    """
    # 1. Extract user ID from token
    user_id_str = token_payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token - missing user ID"
        )
    
    user_id = uuid.UUID(user_id_str)
    
    # 2. Verify user exists and has 'official' role
    from app.models.user import User
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
    
    # 3. Verify incident exists
    db_incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not db_incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Requested Incident ID not found."
        )
    
    # 4. Validate status is one of allowed values
    ALLOWED_STATUSES = {"Pending", "In Progress", "Resolved", "Rejected"}
    if payload.status not in ALLOWED_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of: {', '.join(ALLOWED_STATUSES)}"
        )
        
    # 5. Update incident status
    old_status = db_incident.status
    db_incident.status = payload.status
    
    # 6. Log audit trail transaction
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
    
    # Coordinate extraction with error handling
    try:
        lon_coord = db.scalar(func.ST_X(db_incident.location.cast(func.geometry)))
        lat_coord = db.scalar(func.ST_Y(db_incident.location.cast(func.geometry)))
    except Exception as e:
        import logging
        logging.error(f"Failed to extract coordinates for incident {db_incident.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to extract incident location coordinates"
        )
    
    return IncidentResponse(
        id=db_incident.id,
        status=db_incident.status,
        category=db_incident.category,
        description=db_incident.description,
        image_url=db_incident.image_url,
        latitude=lat_coord,
        longitude=lon_coord,
        created_at=db_incident.created_at,
        updated_at=db_incident.updated_at
    )
