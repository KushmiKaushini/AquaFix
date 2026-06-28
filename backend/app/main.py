import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.database import engine, Base
from app.api.v1.incidents import router as incident_router
from app.api.v1.auth import router as auth_router

# Run database migrations on startup
def run_migrations():
    """Run database migrations if needed."""
    try:
        import sys
        from pathlib import Path
        migrations_dir = Path(__file__).parent.parent / "migrations"
        sys.path.insert(0, str(migrations_dir))
        
        from run_migrations import run_migrations as execute_migrations
        if execute_migrations():
            print("✅ Database migrations completed successfully")
        else:
            print("⚠️ Some migrations may have failed, continuing startup...")
    except Exception as e:
        print(f"⚠️ Could not run migrations: {str(e)}")
        print("Attempting direct table creation instead...")

# Attempt automatic database creation on startup
try:
    run_migrations()
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables successfully created/verified.")
except Exception as e:
    print(f"⚠️ Automatic database table initialization skipped: {str(e)}")
    print("Ensure PostgreSQL is running and PostGIS extension is loaded.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="AquaFix Crowdsourced Public Sanitation & Infrastructure Reporting Platform Backend API Gateway",
    version="1.0.0"
)

# Initialize rate limiter
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter


@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request, exc):
    return JSONResponse(
        status_code=429,
        content={"detail": f"Rate limit exceeded. Maximum {settings.RATE_LIMIT_PER_MINUTE} requests per minute"},
    )


# Set CORS origins to only allow the configured frontend URL
app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

# Mount uploads directory as static files
UPLOAD_DIR = os.path.join(os.getcwd(), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Include API routers
app.include_router(auth_router, tags=["Authentication"])
app.include_router(incident_router, prefix="/api/v1/incidents", tags=["Incidents"])

# Health check endpoint
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for load balancers and monitoring."""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }


@app.get("/", tags=["Root"])
async def root():
    """API root endpoint with documentation links."""
    return {
        "name": settings.PROJECT_NAME,
        "version": "1.0.0",
        "docs": "/docs",
        "openapi": "/openapi.json"
    }
