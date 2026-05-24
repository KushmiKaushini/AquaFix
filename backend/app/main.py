import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.core.config import settings
from app.core.database import engine, Base
from app.api.v1.incidents import router as incident_router

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

# Set CORS origins to allow any developmental mobile environment connectivity
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Route registration
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
