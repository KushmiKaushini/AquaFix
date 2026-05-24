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

# Attempt automatic database creation on startup
# Useful for local quickstart environments
try:
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables successfully created.")
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

# Route registration
app.include_router(auth_router)
app.include_router(
    incident_router,
    prefix=f"{settings.API_V1_STR}/incidents",
    tags=["Incidents"]
)

# Statically serve images uploaded by citizens
UPLOAD_DIR = os.path.join(os.getcwd(), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": settings.PROJECT_NAME,
        "message": "Welcome to AquaFix API Portal. Access Swagger docs at /docs."
    }
