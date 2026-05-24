# AquaFix - Project Development Plan
**Last Updated:** May 24, 2026  
**Status:** MVP with Critical Gaps  
**Target:** Production-Ready Deployment

---

## Executive Summary

AquaFix is a **crowdsourced infrastructure reporting platform** with a working MVP. The current codebase has solid architecture but requires hardening across security, performance, and testing before production.

**Timeline to Production:** 4-6 weeks with dedicated 1-2 person team  
**Current Blockers:** 5 critical security issues, missing authentication  
**Risk Level:** 🔴 HIGH - Security & Data Loss (fixable in short term)

---

## Strategic Roadmap

```
├─ Phase 1: SECURITY & FOUNDATION (Weeks 1-2) 🔴 CRITICAL
│  ├─ User Authentication System
│  ├─ Security Hardening
│  └─ Basic Authorization (RBAC)
│
├─ Phase 2: PERFORMANCE & STABILITY (Weeks 2-3) 🟠 HIGH
│  ├─ Database Optimization
│  ├─ Query Performance Fixes
│  └─ Error Handling & Logging
│
├─ Phase 3: QUALITY ASSURANCE (Weeks 3-4) 🟡 MEDIUM
│  ├─ Unit Tests
│  ├─ Integration Tests
│  └─ End-to-End Testing
│
├─ Phase 4: FEATURE COMPLETION (Weeks 4-6) 🟡 MEDIUM
│  ├─ Frontend Features
│  ├─ Backend Features
│  └─ Infrastructure Setup
│
└─ Phase 5: DEPLOYMENT PREP (Week 6+) 🟢 ONGOING
   ├─ Cloud Migration
   ├─ Monitoring & Alerts
   └─ Documentation
```

---

## Phase 1: Security & Foundation (Weeks 1-2)

### 1.1 User Authentication System

**Sprint Goal:** Implement complete authentication flow  
**Team:** 1-2 developers  
**Duration:** 5 days

#### Tasks

| Task | Owner | Status | Duration | Dependencies |
|------|-------|--------|----------|--------------|
| 1.1.1 | Create User registration endpoint | Backend Dev | 📋 TODO | 1 day | None |
| 1.1.2 | Implement JWT token generation | Backend Dev | 📋 TODO | 1 day | 1.1.1 |
| 1.1.3 | Add login endpoint | Backend Dev | 📋 TODO | 1 day | 1.1.2 |
| 1.1.4 | Create auth middleware | Backend Dev | 📋 TODO | 1 day | 1.1.3 |
| 1.1.5 | Protect incident endpoints with auth | Backend Dev | 📋 TODO | 1 day | 1.1.4 |
| 1.1.6 | Add password reset endpoint | Backend Dev | 📋 TODO | 1 day | 1.1.1 |
| 1.1.7 | Create Flutter login screen | Frontend Dev | 📋 TODO | 1.5 days | 1.1.3 |
| 1.1.8 | Add token storage (secure_storage) | Frontend Dev | 📋 TODO | 1 day | 1.1.7 |
| 1.1.9 | Update API service with auth headers | Frontend Dev | 📋 TODO | 0.5 days | 1.1.8 |
| 1.1.10 | Test auth flow end-to-end | QA | 📋 TODO | 1 day | 1.1.9 |

#### Implementation Details

**Backend: User Registration (1.1.1)**
```python
# POST /api/v1/users/register
from pydantic import EmailStr

class UserRegister(BaseModel):
    email: EmailStr
    password: str  # min 8 chars, complexity required
    full_name: str

@router.post("/register", response_model=UserResponse, status_code=201)
async def register_user(payload: UserRegister, db: Session = Depends(get_db)):
    # Check if user exists
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Hash password with bcrypt
    hashed = get_password_hash(payload.password)
    user = User(email=payload.email, hashed_password=hashed, full_name=payload.full_name)
    db.add(user)
    db.commit()
    return user
```

**Backend: JWT Token Generation (1.1.2)**
```python
# POST /api/v1/users/login
from datetime import timedelta
from jose import jwt

@router.post("/login")
async def login(email: str, password: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    token_data = {"sub": str(user.id), "role": user.role}
    token = jwt.encode(
        token_data,
        settings.SECRET_KEY,
        algorithm="HS256",
        expires_in=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": token, "token_type": "bearer"}
```

**Backend: Auth Middleware (1.1.4)**
```python
from fastapi import Depends, HTTPException

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# Usage:
@router.patch("/{incident_id}/status", dependencies=[Depends(get_current_user)])
def update_incident_status(...):
    pass
```

**Frontend: Login Screen (1.1.7)**
```dart
// lib/screens/auth/login_screen.dart
class LoginScreen extends ConsumerWidget {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: "Password")),
            ElevatedButton(
              onPressed: () async {
                try {
                  final result = await apiService.login(
                    email: _emailController.text,
                    password: _passwordController.text,
                  );
                  await _saveToken(result['access_token']);
                  // Navigate to home
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed: $e")));
                }
              },
              child: Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 1.2 Security Hardening

**Sprint Goal:** Fix critical security vulnerabilities  
**Duration:** 3 days

#### 1.2.1 Secrets Management

**CURRENT (❌ INSECURE):**
```python
# app/core/config.py
SECRET_KEY: str = "temporary-secret-key-change-in-production"
```

**FIXED (✅ SECURE):**
```python
from pydantic import Field

class Settings(BaseSettings):
    SECRET_KEY: str = Field(..., env="SECRET_KEY")  # REQUIRED
    GEMINI_API_KEY: str = Field("", env="GEMINI_API_KEY")
    DATABASE_URL: str = Field(..., env="DATABASE_URL")
    
    # Validation
    @field_validator("SECRET_KEY")
    @classmethod
    def secret_key_strength(cls, v):
        if len(v) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters")
        return v
```

**Deployment:**
```bash
# Create .env file (never commit!)
SECRET_KEY="generated-with-openssl-rand-hex-32"
DATABASE_URL="postgresql://user:pass@host:5432/aquafix"
GEMINI_API_KEY="AIzaSy..."

# Load in deployment
export $(cat .env | xargs)
uvicorn app.main:app
```

#### 1.2.2 CORS Configuration

**CURRENT (❌ OPEN TO ALL):**
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # SECURITY RISK!
)
```

**FIXED (✅ RESTRICTED):**
```python
import os

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "localhost:3000").split(","),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["X-Total-Count"],
    max_age=600,
)
```

#### 1.2.3 Rate Limiting

**Add to requirements.txt:**
```
slowapi>=0.1.9
```

**Implementation:**
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/api/v1/incidents/report")
@limiter.limit("5/minute")  # 5 reports per minute per IP
async def report_incident(...):
    pass
```

#### 1.2.4 Password Security

**Add to requirements.txt:**
```
argon2-cffi>=21.3.0
```

**Update password hashing:**
```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)
```

### 1.3 Role-Based Access Control (RBAC)

**Duration:** 2 days

```python
from enum import Enum

class UserRole(str, Enum):
    CITIZEN = "citizen"
    OFFICIAL = "official"
    ADMIN = "admin"

# Update User model
class User(Base):
    role = Column(String(50), default="citizen")

# Authorization decorator
def require_role(*roles: UserRole):
    def decorator(func):
        async def wrapper(current_user = Depends(get_current_user), *args, **kwargs):
            if current_user.role not in roles:
                raise HTTPException(status_code=403, detail="Insufficient permissions")
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# Usage:
@router.patch("/{incident_id}/status")
@require_role(UserRole.OFFICIAL, UserRole.ADMIN)
def update_incident_status(...):
    pass
```

---

## Phase 2: Performance & Stability (Weeks 2-3)

### 2.1 Database Optimization

**Duration:** 3 days

#### 2.1.1 Add Spatial Index

```sql
-- Run in PostgreSQL
CREATE INDEX idx_incidents_location ON incidents USING GIST(location);
CREATE INDEX idx_incidents_status ON incidents(status);
CREATE INDEX idx_incidents_created_at ON incidents(created_at DESC);
CREATE INDEX idx_incidents_reporter_id ON incidents(reporter_id);
CREATE INDEX idx_audit_incident_id ON incident_audit_trail(incident_id);
```

**Django Migration Alternative:**
```python
# app/migrations/0001_add_indexes.py
class Migration(migrations.Migration):
    operations = [
        migrations.RunSQL(
            sql="CREATE INDEX idx_incidents_location ON incidents USING GIST(location);",
            reverse_sql="DROP INDEX idx_incidents_location;"
        ),
    ]
```

#### 2.1.2 Fix N+1 Query Problem

**CURRENT (❌ 100+ queries for 100 incidents):**
```python
incidents = db.query(Incident).all()
for inc in incidents:
    lon = db.scalar(func.ST_X(inc.location.cast(func.geometry)))  # Query per incident!
```

**FIXED (✅ Single query):**
```python
from sqlalchemy import select, cast
from geoalchemy2.functions import ST_X, ST_Y

query = select(
    Incident,
    cast(func.ST_X(Incident.location), Float).label("longitude"),
    cast(func.ST_Y(Incident.location), Float).label("latitude")
)
results = db.execute(query).all()
```

#### 2.1.3 Query Optimization for Spatial Searches

```python
# Optimized spatial query with status filter
def read_incidents_optimized(
    status_filter: Optional[str] = None,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    radius: Optional[float] = None,
    db: Session = Depends(get_db)
):
    query = db.query(
        Incident,
        func.ST_X(cast(Incident.location, func.geometry)).label("lon_coord"),
        func.ST_Y(cast(Incident.location, func.geometry)).label("lat_coord")
    )
    
    if status_filter:
        query = query.filter(Incident.status == status_filter)
    
    if lat is not None and lon is not None and radius is not None:
        point = f"SRID=4326;POINT({lon} {lat})"
        query = query.filter(func.ST_DWithin(Incident.location, point, radius))
    
    return query.all()
```

### 2.2 Pagination Implementation

**Duration:** 2 days

```python
from pydantic import BaseModel

class PaginationParams(BaseModel):
    skip: int = Query(0, ge=0)
    limit: int = Query(20, ge=1, le=100)

class PaginatedResponse(BaseModel, Generic[T]):
    total: int
    items: List[T]
    skip: int
    limit: int

@router.get("/", response_model=PaginatedResponse[IncidentResponse])
def read_incidents(
    status_filter: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db)
):
    total = db.query(func.count(Incident.id)).scalar()
    incidents = db.query(Incident).offset(skip).limit(limit).all()
    
    return PaginatedResponse(
        total=total,
        items=[IncidentResponse.from_orm(inc) for inc in incidents],
        skip=skip,
        limit=limit
    )
```

**Frontend Pagination:**
```dart
// lib/screens/incidents_list_screen.dart
class IncidentsListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: apiService.getIncidents(skip: 0, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data as Map;
          return ListView(
            children: [
              ...data['items'].map((inc) => IncidentCard(incident: inc)),
              if (data['skip'] + data['limit'] < data['total'])
                ElevatedButton(
                  onPressed: () => loadMore(),
                  child: Text("Load More")
                ),
            ],
          );
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

### 2.3 Error Handling & Logging

**Duration:** 2 days

#### 2.3.1 Add Structured Logging

**Add to requirements.txt:**
```
python-json-logger>=2.0.7
```

**Configuration:**
```python
# app/core/logging.py
import logging
import logging.config

LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        },
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
        }
    },
    "handlers": {
        "default": {
            "formatter": "default",
            "class": "logging.StreamHandler",
        },
        "json": {
            "formatter": "json",
            "class": "logging.handlers.RotatingFileHandler",
            "filename": "logs/aquafix.log",
        }
    },
    "loggers": {
        "aquafix": {
            "handlers": ["default", "json"],
            "level": "INFO",
            "propagate": True,
        }
    }
}

logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger("aquafix")
```

#### 2.3.2 Global Error Handler

```python
from fastapi import Request
from fastapi.exceptions import RequestValidationError

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=exc)
    return {
        "status_code": 500,
        "detail": "Internal server error",
        "request_id": request.headers.get("X-Request-ID", "unknown")
    }

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.warning(f"Validation error: {exc.errors()}")
    return {
        "status_code": 422,
        "detail": exc.errors()
    }
```

---

## Phase 3: Quality Assurance (Weeks 3-4)

### 3.1 Backend Testing

**Duration:** 5 days

#### 3.1.1 Unit Tests Structure

```
backend/tests/
├── __init__.py
├── conftest.py               # Pytest fixtures
├── test_models.py
├── test_schemas.py
├── test_services/
│   └── test_gemini.py
└── test_api/
    ├── test_incidents.py
    ├── test_users.py
    └── test_auth.py
```

#### 3.1.2 Example Tests

**conftest.py** - Setup & fixtures:
```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.database import Base
from app.core.config import settings

TEST_DATABASE_URL = "sqlite:///./test.db"

@pytest.fixture
def test_db():
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def test_client(test_db):
    from fastapi.testclient import TestClient
    from app.main import app
    
    def override_get_db():
        yield test_db
    
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()
```

**test_api/test_incidents.py:**
```python
def test_report_incident_success(test_client, test_db):
    # Create test image
    image_data = b"fake image data"
    
    response = test_client.post(
        "/api/v1/incidents/report",
        data={
            "latitude": 28.6139,
            "longitude": 77.2090,
            "description": "Pipeline leak"
        },
        files={"file": ("test.jpg", image_data, "image/jpeg")}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "Pending"
    assert data["latitude"] == 28.6139

def test_report_incident_invalid_coords(test_client):
    response = test_client.post(
        "/api/v1/incidents/report",
        data={"latitude": 100, "longitude": 77.2090}  # Invalid
    )
    assert response.status_code == 422

def test_get_incidents_with_pagination(test_client, test_db):
    response = test_client.get("/api/v1/incidents/?skip=0&limit=10")
    assert response.status_code == 200
    assert "total" in response.json()
    assert "items" in response.json()

def test_spatial_query(test_client, test_db):
    # First create incident
    # Then query by radius
    response = test_client.get("/api/v1/incidents/?lat=28.6139&lon=77.2090&radius=5000")
    assert response.status_code == 200
```

### 3.2 Frontend Testing

**Duration:** 3 days

**Add to pubspec.yaml:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  integration_test:
    sdk: flutter
```

**Unit Tests:**
```dart
// test/services/api_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:aquafix/services/api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('ApiService', () {
    late MockHttpClient mockClient;
    late ApiService apiService;
    
    setUp(() {
      mockClient = MockHttpClient();
      apiService = ApiService();
    });
    
    test('submitIncident returns incident data on success', () async {
      when(mockClient.send(any)).thenAnswer((_) async =>
        http.StreamedResponse(
          Stream.value(utf8.encode('{"id":"123","status":"Pending"}')),
          201,
        )
      );
      
      final result = await apiService.submitIncident(
        imagePath: 'test.jpg',
        latitude: 28.6139,
        longitude: 77.2090,
        description: 'Test'
      );
      
      expect(result['status'], equals('Pending'));
    });
    
    test('submitIncident throws on API error', () async {
      when(mockClient.send(any)).thenAnswer((_) async =>
        http.StreamedResponse(
          Stream.value(utf8.encode('{"detail":"Spam detected"}')),
          400,
        )
      );
      
      expect(
        () => apiService.submitIncident(...),
        throwsException
      );
    });
  });
}
```

**Integration Tests:**
```dart
// integration_test/incident_reporter_test.dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquafix/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('User can report incident', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Tap image picker button
    await tester.tap(find.byType(ImagePickerButton));
    await tester.pumpAndSettle();
    
    // Enter description
    await tester.enterText(find.byType(TextField), 'Pipeline leak');
    
    // Tap submit
    await tester.tap(find.byType(SubmitButton));
    await tester.pumpAndSettle();
    
    // Verify success message
    expect(find.byType(SuccessDialog), findsOneWidget);
  });
}
```

### 3.3 Test Coverage Goal

- **Backend:** ≥80% coverage
- **Frontend:** ≥60% coverage (especially services and providers)

```bash
# Generate coverage report
pytest --cov=app --cov-report=html tests/

# View report
open htmlcov/index.html
```

---

## Phase 4: Feature Completion (Weeks 4-6)

### 4.1 Frontend Features

| Feature | Owner | Duration | Priority | MVP |
|---------|-------|----------|----------|-----|
| **Incident List Screen** | Frontend | 2 days | 🔴 CRITICAL | ✅ Yes |
| **Map View** | Frontend | 3 days | 🟠 HIGH | ❌ Later |
| **User Profile Screen** | Frontend | 1.5 days | 🟠 HIGH | ✅ Yes |
| **Incident Detail View** | Frontend | 2 days | 🟠 HIGH | ✅ Yes |
| **Settings Screen** | Frontend | 1 day | 🟡 MEDIUM | ✅ Yes |
| **Offline Sync** | Frontend | 4 days | 🟡 MEDIUM | ❌ Later |
| **Push Notifications** | Frontend | 3 days | 🟡 MEDIUM | ❌ Later |

### 4.2 Backend Features

| Feature | Owner | Duration | Priority | MVP |
|---------|-------|----------|----------|-----|
| **Image Upload to S3** | Backend | 2 days | 🔴 CRITICAL | ✅ Yes |
| **Text Search** | Backend | 2 days | 🟠 HIGH | ✅ Yes |
| **Date Range Filtering** | Backend | 1 day | 🟠 HIGH | ✅ Yes |
| **Admin Dashboard API** | Backend | 3 days | 🟡 MEDIUM | ❌ Later |
| **Analytics API** | Backend | 2 days | 🟡 MEDIUM | ❌ Later |
| **Bulk Operations** | Backend | 2 days | 🟡 MEDIUM | ❌ Later |
| **Export (CSV/JSON)** | Backend | 2 days | 🟡 MEDIUM | ❌ Later |

### 4.3 Image Upload to Cloud Storage

**Why:** Filesystem storage doesn't scale; use AWS S3 or Google Cloud Storage

**Add to requirements.txt:**
```
boto3>=1.28.0  # AWS S3
google-cloud-storage>=2.10.0  # Google Cloud Storage
```

**Implementation (AWS S3):**
```python
import boto3
from botocore.exceptions import ClientError

class S3ImageService:
    def __init__(self):
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY,
            aws_secret_access_key=settings.AWS_SECRET_KEY,
            region_name=settings.AWS_REGION
        )
        self.bucket = settings.S3_BUCKET_NAME
    
    async def upload_image(self, file: UploadFile) -> str:
        """Upload image to S3, return public URL"""
        try:
            key = f"incidents/{uuid.uuid4()}{os.path.splitext(file.filename)[1]}"
            
            self.s3_client.upload_fileobj(
                file.file,
                self.bucket,
                key,
                ExtraArgs={'ContentType': file.content_type}
            )
            
            return f"https://{self.bucket}.s3.amazonaws.com/{key}"
        except ClientError as e:
            logger.error(f"S3 upload failed: {e}")
            raise HTTPException(status_code=500, detail="Image upload failed")

# Usage in incidents endpoint
@router.post("/report")
async def report_incident(file: UploadFile = File(...)):
    image_url = await s3_service.upload_image(file)
    # ... rest of logic
```

### 4.4 Text Search Implementation

```python
from sqlalchemy import or_

@router.get("/search")
def search_incidents(
    query: str = Query(..., min_length=2, max_length=100),
    db: Session = Depends(get_db)
):
    """Full-text search on incident descriptions and categories"""
    results = db.query(Incident).filter(
        or_(
            Incident.description.ilike(f"%{query}%"),
            Incident.category.ilike(f"%{query}%")
        )
    ).limit(50).all()
    
    return [IncidentResponse.from_orm(inc) for inc in results]

# For PostgreSQL full-text search (faster):
from sqlalchemy import text

@router.get("/search/fulltext")
def fulltext_search(query: str, db: Session = Depends(get_db)):
    results = db.query(Incident).filter(
        text(f"to_tsvector(description) @@ plainto_tsquery('{query}')")
    ).all()
    return results
```

---

## Phase 5: Deployment Preparation (Week 6+)

### 5.1 Infrastructure Setup

#### 5.1.1 Docker Containerization

**backend/Dockerfile:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install PostGIS dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY .env .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**frontend/Dockerfile:**
```dockerfile
FROM flutter:latest

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build apk --release

FROM ubuntu:latest
RUN apt-get update && apt-get install -y android-tools-adb
COPY --from=0 /app/build/app/outputs/flutter-apk/app-release.apk /app.apk

EXPOSE 8080
CMD ["adb", "install", "/app.apk"]
```

#### 5.1.2 Kubernetes Manifests

**k8s/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aquafix-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: aquafix-backend
  template:
    metadata:
      labels:
        app: aquafix-backend
    spec:
      containers:
      - name: api
        image: aquafix-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: aquafix-secrets
              key: database-url
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: aquafix-secrets
              key: secret-key
        livenessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
```

### 5.2 Monitoring & Alerting

**Add to requirements.txt:**
```
prometheus-client>=0.17.0
sentry-sdk>=1.25.0
```

**Monitoring Setup:**
```python
from prometheus_client import Counter, Histogram, Gauge
from sentry_sdk import init as sentry_init

# Initialize Sentry
sentry_init(dsn=settings.SENTRY_DSN)

# Prometheus metrics
incident_reports = Counter('incidents_total', 'Total incident reports')
api_requests = Histogram('api_request_duration_seconds', 'API request duration')
active_users = Gauge('active_users', 'Number of active users')

@router.post("/report")
@api_requests.time()
async def report_incident(...):
    incident_reports.inc()
    # ...
```

### 5.3 Database Backups

**Automated Backup Script:**
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/aquafix"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

pg_dump -U postgres -h $DB_HOST $DB_NAME > "$BACKUP_DIR/aquafix_$TIMESTAMP.sql"

# Upload to S3
aws s3 cp "$BACKUP_DIR/aquafix_$TIMESTAMP.sql" s3://aquafix-backups/

# Cleanup old backups (keep 7 days)
find $BACKUP_DIR -mtime +7 -delete
```

**Cron Schedule:**
```cron
# Daily backup at 2 AM
0 2 * * * /scripts/backup.sh >> /var/log/backup.log 2>&1
```

---

## Critical Path (Minimum Viable Timeline)

### Week 1-2: Security & Auth
- [ ] Day 1-2: JWT authentication endpoints
- [ ] Day 3: Auth middleware & token validation
- [ ] Day 4: Flutter login UI
- [ ] Day 5: CORS & rate limiting hardening
- [ ] Day 6-7: Testing & fixes

### Week 2-3: Performance
- [ ] Day 1-2: Database indexes & query optimization
- [ ] Day 3-4: Pagination implementation
- [ ] Day 5-6: Logging & error handling
- [ ] Day 7: Performance testing

### Week 3-4: Testing
- [ ] Day 1-3: Backend test suite
- [ ] Day 4-5: Frontend test suite
- [ ] Day 6-7: Integration testing

### Week 4-5: Features & Cloud
- [ ] Day 1-2: S3 image upload
- [ ] Day 3: Text search
- [ ] Day 4: Incident list UI
- [ ] Day 5: Docker containerization
- [ ] Day 6-7: Bug fixes

### Week 5-6: Deployment
- [ ] Day 1-2: Kubernetes setup
- [ ] Day 3-4: Monitoring & backups
- [ ] Day 5-6: Load testing
- [ ] Day 7: Production deployment

---

## Success Metrics

### Backend Metrics
- ✅ All endpoints protected by authentication
- ✅ API response time <200ms (p95)
- ✅ Database queries <100ms average
- ✅ Zero security vulnerabilities (per OWASP)
- ✅ 80%+ test coverage
- ✅ All critical indexes created

### Frontend Metrics
- ✅ App startup time <3 seconds
- ✅ Image upload <10MB
- ✅ Location acquisition <10 seconds
- ✅ 60%+ test coverage
- ✅ App size <50MB
- ✅ Works offline (basic features)

### Infrastructure Metrics
- ✅ 99.9% uptime SLA
- ✅ Automated backups verified
- ✅ <1 minute deployment time
- ✅ All secrets in secure vaults
- ✅ Logging centralized & searchable

---

## Resource Requirements

### Team Composition
- **1-2 Backend Engineers** (Python/FastAPI)
- **1 Frontend Engineer** (Flutter/Dart)
- **1 DevOps/Infrastructure** (Part-time)
- **1 QA** (Part-time)

### Infrastructure Costs (Monthly)
| Service | Estimated Cost |
|---------|-----------------|
| PostgreSQL/PostGIS (AWS RDS) | $50-100 |
| S3 Image Storage | $10-50 |
| Kubernetes (EKS) | $100-200 |
| Gemini API (usage-based) | $20-100 |
| **TOTAL** | **$180-450** |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Gemini API rate limits | Medium | High | Cache results, batch requests |
| Database migration issues | Low | High | Test migrations on staging first |
| Auth implementation bugs | High | High | Extensive testing + security audit |
| Image storage capacity | Low | Medium | Implement cleanup job |
| Team availability | Medium | Medium | Overlap hiring/training |

---

## Success Definition

**MVP is Production-Ready when:**
1. ✅ All CRITICAL security issues fixed (see Phase 1)
2. ✅ Authentication implemented & tested
3. ✅ Database optimized & indexed
4. ✅ Test coverage >80% backend, >60% frontend
5. ✅ Incident reports working end-to-end
6. ✅ Rate limiting & CORS configured
7. ✅ Deployment automated (Docker/K8s)
8. ✅ Monitoring & alerting active
9. ✅ Backups automated & tested
10. ✅ Documentation complete

**Estimated Launch:** Week 6 (30 days from audit)

---

**Document Status:** Active Planning  
**Last Updated:** May 24, 2026  
**Next Review:** Weekly sprint retrospectives
