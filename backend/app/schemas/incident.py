from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional, List

# Valid status values
VALID_STATUSES = {"Pending", "In Progress", "Resolved", "Rejected"}
VALID_CATEGORIES = {
    "Pipeline Leak", "Drainage Blockage", "Overflowing Sewage",
    "Road Sinkhole", "Public Sanitation Issue"
}

class IncidentBase(BaseModel):
    description: Optional[str] = Field(None, max_length=1000, description="Incident description")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS Latitude coordinate")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS Longitude coordinate")

class IncidentCreate(IncidentBase):
    pass

class IncidentStatusUpdate(BaseModel):
    status: str = Field(
        ...,
        description=f"Target status. Must be one of: {', '.join(VALID_STATUSES)}"
    )
    internal_notes: Optional[str] = Field(
        None,
        max_length=500,
        description="Official notes detailing work action"
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "status": "In Progress",
                "internal_notes": "Field team dispatched to assess damage"
            }
        }

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

class PaginatedIncidentResponse(BaseModel):
    """Paginated incident list response."""
    items: List[IncidentResponse]
    total: int = Field(description="Total number of incidents matching filter")
    skip: int = Field(description="Number of incidents skipped")
    limit: int = Field(description="Maximum incidents returned")
    
    @property
    def page(self) -> int:
        """Calculate current page number."""
        return (self.skip // self.limit) + 1 if self.limit > 0 else 1
    
    @property
    def total_pages(self) -> int:
        """Calculate total number of pages."""
        return (self.total + self.limit - 1) // self.limit if self.limit > 0 else 1
    }
