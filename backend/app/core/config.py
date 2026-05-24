import os
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, field_validator

class Settings(BaseSettings):
    PROJECT_NAME: str = "AquaFix API"
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = Field(description="Secret key for JWT signing - MUST be set in production")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    
    # Database
    DATABASE_URL: str = Field(description="PostgreSQL database URL - MUST be set")
    
    # Gemini API Key
    GEMINI_API_KEY: str = Field(default="", description="Google Gemini API key for image analysis")
    
    # CORS
    FRONTEND_URL: str = Field(default="http://localhost:3000", description="Frontend URL for CORS")
    
    # Rate limiting
    RATE_LIMIT_PER_MINUTE: int = 60

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

    @field_validator("DATABASE_URL")
    @classmethod
    def assemble_db_connection(cls, v: str) -> str:
        if v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

# Instantiate settings
settings = Settings()
