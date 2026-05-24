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
    """
    # 1. Read binary image bytes
    image_bytes = await file.read()
    
    # 2. Call Gemini Vision API
    gemini_result = await gemini_service.verify_and_categorize_incident(
        image_bytes=image_bytes, 
        mime_type=file.content_type or "image/jpeg"
    )
    
    # 3. Spam filtering checks
    if not gemini_result.get("is_infrastructure_issue", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Spam Filter Rejection: {gemini_result.get('reasoning', 'Not a valid sanitation/infrastructure issue.')}"
        )

    # 4. Save file locally for verification
    file_extension = os.path.splitext(file.filename)[1] if file.filename else ".jpg"
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    filepath = os.path.join(UPLOAD_DIR, unique_filename)
    
    # Reset stream pointer and save
    await file.seek(0)
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Define local accessible asset URL
    image_url = f"/uploads/{unique_filename}"
    
    # 5. Build spatial coordinate string for PostGIS Point mapping
    # Note: PostGIS POINT parameters take Longitude first, then Latitude
    wkt_location = f"SRID=4326;POINT({longitude} {latitude})"
    
    # 6. Create SQL model
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
    
    # 7. Add initial audit trail log
    db_audit = IncidentAuditTrail(
        incident_id=db_incident.id,
        new_status="Pending",
        internal_notes="Incident ingested and automatically verified by Google Gemini 1.5 Flash Vision API."
    )
    db.add(db_audit)
    db.commit()
    
    # 8. Transform db representation to coordinate outputs for Pydantic mapping
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

@router.get("/", response_model=List[IncidentResponse])
def read_incidents(
    status_filter: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    radius: Optional[float] = None,  # in meters
    db: Session = Depends(get_db)
):
    """
    Get incidents, with optional support for status filtering and geocentric radial distance queries (PostGIS).
    """
    query = db.query(Incident)
    
    if status_filter:
        query = query.filter(Incident.status == status_filter)
        
    # Implement PostGIS radial query if lat, lon, and radius are supplied
    if lat is not None and lon is not None and radius is not None:
        point = f"SRID=4326;POINT({lon} {lat})"
        # ST_DWithin handles spatial geography distance checking
        query = query.filter(func.ST_DWithin(Incident.location, point, radius))
        
    incidents = query.all()
    
    # Convert PostGIS POINT shape to raw latitude/longitude floats for response serialization
    results = []
    for inc in incidents:
        # Resolve the geography field coordinates via SQLAlchemy ST_AsText helper or raw SQL projection
        # For lightweight standard parsing, we can fetch lon/lat directly from PostGIS features
        lon_coord = db.scalar(func.ST_X(inc.location.cast(func.geometry)))
        lat_coord = db.scalar(func.ST_Y(inc.location.cast(func.geometry)))
        
        results.append(
            IncidentResponse(
                id=inc.id,
                status=inc.status,
                category=inc.category,
                description=inc.description,
                image_url=inc.image_url,
                latitude=lat_coord,
                longitude=lon_coord,
                created_at=inc.created_at,
                updated_at=inc.updated_at
            )
        )
        
    return results

@router.patch("/{incident_id}/status", response_model=IncidentResponse)
def update_incident_status(
    incident_id: uuid.UUID,
    payload: IncidentStatusUpdate,
    token_payload: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Update incident status and append tracking record to Audit Trail.
    Requires valid JWT authentication token.
    """
    db_incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not db_incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Requested Incident ID not found."
        )
        
    old_status = db_incident.status
    db_incident.status = payload.status
    
    # Get user ID from token
    user_id = token_payload.get("sub")
    
    # Log audit trail transaction
    db_audit = IncidentAuditTrail(
        incident_id=db_incident.id,
        modified_by=uuid.UUID(user_id) if user_id else None,
        old_status=old_status,
        new_status=payload.status,
        internal_notes=payload.internal_notes or f"Status updated by Official review."
    )
    db.add(db_audit)
    db.commit()
    db.refresh(db_incident)
    
    # Coordinate extraction
    lon_coord = db.scalar(func.ST_X(db_incident.location.cast(func.geometry)))
    lat_coord = db.scalar(func.ST_Y(db_incident.location.cast(func.geometry)))
    
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
