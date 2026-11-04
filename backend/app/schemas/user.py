from pydantic import BaseModel, EmailStr, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional

class UserBase(BaseModel):
    email: EmailStr
    full_name: str
    role: str = "citizen"  # 'citizen' or 'official'

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class DeviceTokenUpdate(BaseModel):
    fcm_token: str

class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    fcm_token: Optional[str] = None
    created_at: datetime

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    email: Optional[str] = None
