from pydantic import BaseModel, Field, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any

# Valid domain values
VALID_STATUSES = {"Pending", "In Progress", "Resolved", "Rejected"}
VALID_SEVERITIES = {"Low", "Medium", "High", "Critical"}
VALID_CATEGORIES = {
    "Pipeline Leak",
    "Drainage Blockage",
    "Overflowing Sewage",
    "Road Sinkhole",
    "Public Sanitation Issue",
}

class IncidentBase(BaseModel):
    category: Optional[str] = Field(default="Public Sanitation Issue", description="Incident category")
    severity: Optional[str] = Field(default="Medium", description="Incident severity: Low, Medium, High, Critical")
    description: Optional[str] = Field(None, max_length=1000, description="Incident description")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS Latitude coordinate")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS Longitude coordinate")

class IncidentCreate(IncidentBase):
    pass

class IncidentStatusUpdate(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "status": "In Progress",
                "severity": "High",
                "internal_notes": "Field team dispatched to assess pipeline damage"
            }
        }
    )
    status: str = Field(
        ...,
        description=f"Target status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"
    )
    severity: Optional[str] = Field(
        None,
        description=f"Optional updated severity level: {', '.join(sorted(VALID_SEVERITIES))}"
    )
    internal_notes: Optional[str] = Field(
        None,
        max_length=500,
        description="Official notes detailing work action"
    )

class IncidentAuditResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    incident_id: UUID
    modified_by: Optional[UUID] = None
    modifier_name: Optional[str] = None
    old_status: Optional[str] = None
    new_status: str
    internal_notes: Optional[str] = None
    changed_at: datetime

class AIAnalysisSuggestion(BaseModel):
    is_infrastructure_issue: bool
    category: str
    severity: str = "Medium"
    confidence: float = Field(..., ge=0.0, le=1.0)
    reasoning: str
    visual_markers: Optional[List[str]] = None

class IncidentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    category: str
    severity: str = "Medium"
    description: Optional[str] = None
    image_url: Optional[str] = None
    latitude: float
    longitude: float
    ai_analysis: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime
    reporter_id: Optional[UUID] = None
    history: Optional[List[IncidentAuditResponse]] = None

class PaginatedIncidentResponse(BaseModel):
    """Paginated incident list response."""
    items: List[IncidentResponse]
    total: int = Field(description="Total number of incidents matching filter")
    skip: int = Field(description="Number of incidents skipped")
    limit: int = Field(description="Maximum incidents returned")
    
    @property
    def page(self) -> int:
        return (self.skip // self.limit) + 1 if self.limit > 0 else 1
    
    @property
    def total_pages(self) -> int:
        return (self.total + self.limit - 1) // self.limit if self.limit > 0 else 1
