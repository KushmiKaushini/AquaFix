import uuid
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from geoalchemy2 import Geography
from app.core.database import Base

class Incident(Base):
    __tablename__ = "incidents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reporter_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    status = Column(String(50), default="Pending", nullable=False)  # 'Pending', 'In Progress', 'Resolved', 'Rejected'
    category = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    image_url = Column(String(512), nullable=True)
    
    # PostGIS Spatial Geography coordinate: Point in SRID 4326 (WGS 84)
    location = Column(Geography(geometry_type="POINT", srid=4326), nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
