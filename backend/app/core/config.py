import os
import sys
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, field_validator, ValidationError

class Settings(BaseSettings):
    # Environment & Deployment
    ENVIRONMENT: str = Field(default="development", description="Environment: development, staging, or production")
    PROJECT_NAME: str = "AquaFix API"
    API_V1_STR: str = "/api/v1"
    
    # Security
    SECRET_KEY: str = Field(description="Secret key for JWT signing - MUST be 32+ chars in production")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=60, ge=5, description="JWT token expiration in minutes")
    
    # Database
    DATABASE_URL: str = Field(description="PostgreSQL database URL with PostGIS support")
    
    # AI Service
    GEMINI_API_KEY: str = Field(default="", description="Google Gemini API key for image analysis (optional for mock mode)")
    
    # Frontend CORS
    FRONTEND_URL: str = Field(default="http://localhost:3000", description="Frontend URL for CORS")
    
    # Rate limiting
    RATE_LIMIT_PER_MINUTE: int = Field(default=60, ge=1, description="Rate limit per minute per IP")
    
    # Optional: Sentry for error tracking
    SENTRY_DSN: str = Field(default="", description="Sentry DSN for error tracking (optional)")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

    @field_validator("ENVIRONMENT")
    @classmethod
    def validate_environment(cls, v: str) -> str:
        """Validate environment is one of: development, staging, production."""
        valid_envs = {"development", "staging", "production"}
        if v not in valid_envs:
            raise ValueError(f"ENVIRONMENT must be one of {valid_envs}, got: {v}")
        return v

    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Ensure SECRET_KEY is strong enough for production."""
        if not v:
            raise ValueError("SECRET_KEY is required")
        if len(v) < 16:
            raise ValueError("SECRET_KEY must be at least 16 characters (32+ recommended for production)")
        return v

    @field_validator("DATABASE_URL")
    @classmethod
    def assemble_db_connection(cls, v: str) -> str:
        """Convert old postgres:// URLs to postgresql:// format."""
        if v.startswith("postgres://"):
            v = v.replace("postgres://", "postgresql://", 1)
        return v

    @field_validator("FRONTEND_URL")
    @classmethod
    def validate_frontend_url(cls, v: str) -> str:
        """Ensure FRONTEND_URL is a valid URL."""
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError("FRONTEND_URL must start with http:// or https://")
        return v

# Instantiate settings with validation
try:
    settings = Settings()
    print(f"Configuration loaded successfully (Environment: {settings.ENVIRONMENT})")
except ValidationError as e:
    print("Configuration validation failed:")
    for error in e.errors():
        field = error["loc"][0] if error["loc"] else "unknown"
        msg = error["msg"]
        print(f"  - {field}: {msg}")
    print("\nPlease set the missing environment variables in your .env file.")
    sys.exit(1)
