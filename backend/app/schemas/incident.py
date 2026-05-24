from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional

class IncidentBase(BaseModel):
    description: Optional[str] = None
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS Latitude coordinate")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS Longitude coordinate")

class IncidentCreate(IncidentBase):
    pass

class IncidentStatusUpdate(BaseModel):
    status: str = Field(..., description="Target status (e.g., Pending, In Progress, Resolved, Rejected)")
    internal_notes: Optional[str] = Field(None, description="Official notes detailing work action")

class IncidentResponse(BaseModel):
    id: UUID
    status: str
    category: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    latitude: float
    longitude: float
    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True
    }
