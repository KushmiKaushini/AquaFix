# AquaFix

A complete mobile-plus-API municipal infrastructure reporting and incident management platform with PostGIS spatial tracking and responsible Google Gemini AI assistance.

---

## Overview

AquaFix connects citizens and municipal authorities to report, prioritize, track, and resolve public sanitation and infrastructure incidents—such as pipeline leaks, drainage blockages, overflowing sewage, and road sinkholes.

The platform pairs a responsive Flutter mobile client with a high-performance FastAPI backend, backed by PostgreSQL and PostGIS for geospatial analysis, native bcrypt and JWT security, and human-in-the-loop Gemini Vision AI assistance.

---

## Tech Stack

### Backend
- **Framework**: Python 3.8+ with [FastAPI](https://fastapi.tiangolo.com/)
- **ORM & Database**: [SQLAlchemy 2.0](https://www.sqlalchemy.org/) with PostgreSQL 13+ and [PostGIS](https://postgis.net/) spatial extension
- **Spatial Geometry**: [GeoAlchemy2](https://geoalchemy-2.readthedocs.io/) (`geography(POINT, 4326)`) with GiST spatial indexing and `ST_DWithin` radial queries
- **Authentication**: JWT (HS256) bearer authentication with native `bcrypt` password hashing
- **Rate Limiting**: [SlowAPI](https://github.com/laurentS/slowapi) client IP rate limiter (with configurable limits)
- **AI Integration**: Google Gemini 1.5 Flash Vision for advisory incident classification and feature analysis (with automated offline mock fallback)
- **Testing**: `pytest` with in-memory SQLite and mock spatial dialect

### Frontend
- **Framework**: [Flutter](https://flutter.dev/) (3.x) & Dart SDK
- **State Management**: [Riverpod](https://riverpod.dev/) 2.x
- **Mapping & GIS**: [flutter_map](https://pub.dev/packages/flutter_map) with OpenStreetMap and [geolocator](https://pub.dev/packages/geolocator) for GPS coordinate capture
- **Secure Storage**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) for JWT persistence
- **Architecture**: Modular presentation, domain models, and service layer with full client-side validation

---

## Project Structure

```
AquaFix/
├── backend/
│   ├── app/
│   │   ├── main.py                    # Application entry point, CORS, middlewares, static uploads
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── auth.py            # Registration, login, /me profile, /refresh endpoints
│   │   │       └── incidents.py       # Incident ingestion, AI preview, list, detail, status patch, history
│   │   ├── core/
│   │   │   ├── auth.py                # Native bcrypt hashing, JWT issuance and verification
│   │   │   ├── config.py              # Pydantic Settings management (.env validation)
│   │   │   └── database.py            # SQLAlchemy engine, session factory, declarative base
│   │   ├── models/
│   │   │   ├── audit.py               # IncidentAuditTrail model with User relationship
│   │   │   ├── incident.py            # Incident model with PostGIS Geography, severity, and AI analysis
│   │   │   └── user.py                # User model with citizen/official roles
│   │   ├── schemas/
│   │   │   ├── incident.py            # Pydantic v2 schemas: create, update, response, audit, AI suggestion
│   │   │   └── user.py                # Pydantic v2 schemas: register, login, profile, token
│   │   └── services/
│   │       └── gemini.py              # Gemini 1.5 Flash advisory vision service (with offline mock fallback)
│   ├── migrations/
│   │   ├── 001_add_indexes_and_constraints.sql    # Spatial GiST index, status check, foreign keys
│   │   ├── 002_add_severity_and_ai_analysis.sql   # Severity column, AI metadata JSONB, constraints
│   │   └── run_migrations.py                      # Automated database migration runner
│   ├── tests/
│   │   ├── conftest.py                # Test fixtures, SQLite in-memory spatial mocks, test users
│   │   ├── test_api.py                # Smoke and gateway tests (health, root, CORS)
│   │   ├── test_auth.py               # Registration, login, JWT verification, refresh, role validation
│   │   └── test_incidents.py          # Incident creation, AI preview, lifecycle updates, history, security
│   ├── requirements.txt               # Backend dependencies
│   └── .env.example                   # Environment configuration template
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart                  # Application entry point
│   │   ├── app.dart                   # Riverpod provider scope and MaterialApp theme setup
│   │   ├── config/                    # Environment app configurations
│   │   ├── models/
│   │   │   ├── incident_model.dart    # IncidentModel, IncidentAuditModel, IncidentStatus, Severity helpers
│   │   │   └── user_model.dart        # UserModel and UserRole mapping
│   │   ├── providers/
│   │   │   ├── app_providers.dart     # Riverpod state notifiers for auth and incidents
│   │   │   └── location_provider.dart # Geolocator GPS state management
│   │   ├── screens/
│   │   │   ├── auth/                  # Login and registration screens
│   │   │   ├── dashboard/             # Citizen and official dashboard overview
│   │   │   ├── incidents/
│   │   │   │   ├── incident_detail_screen.dart   # Detail view, interactive map, AI analysis, resolution history
│   │   │   │   ├── incidents_list_screen.dart    # Filterable incident list with status & severity badges
│   │   │   │   └── report_incident_screen.dart   # Report form with GPS lock, photo upload, AI suggestion, manual bypass
│   │   │   ├── onboarding/            # Welcome onboarding walkthrough
│   │   │   ├── profile/               # User account profile and settings
│   │   │   └── splash/                # Startup splash screen
│   │   ├── services/
│   │   │   ├── api_service.dart       # HTTP client: submit, analyze, fetch, update, history
│   │   │   ├── auth_service.dart      # Authentication client with secure token storage
│   │   │   └── api_exceptions.dart    # User-friendly error mapping
│   │   ├── utils/
│   │   │   └── validators.dart        # Coordinates, file type, and file size validation
│   │   └── widgets/
│   │       ├── status_update_dialog.dart # Official status & severity modal
│   │       └── ui_components.dart        # Reusable badges, buttons, cards
│   ├── test/
│   │   └── models_test.dart           # Model serialization, severity, audit, and validation unit tests
│   └── pubspec.yaml                   # Flutter dependencies
│
├── LICENSE
└── README.md
```

---

## Incident Lifecycle Architecture

Every reported infrastructure issue follows a consistent, end-to-end lifecycle across the Flutter form, API endpoints, and database models:

```
[Citizen Form] 
      │ 
      ├─ GPS Coordinates Lock (Latitude / Longitude)
      ├─ Incident Photo Capture (JPEG, PNG, WebP ≤ 5MB)
      ├─ Category & Severity Selection (Editable, or suggested by AI)
      ├─ Optional "Analyze with AI" Advisory Preview
      ├─ Optional "Submit without AI" Manual Bypass
      ▼
[POST /api/v1/incidents/report]
      │
      ├─ File & spatial coordinate validation
      ├─ Gemini advisory analysis (or manual bypass / graceful offline fallback)
      ├─ PostGIS ST_GeogFromText('SRID=4326;POINT(lon lat)') insertion
      ├─ Initial IncidentAuditTrail record logged ("Pending")
      ▼
[Database Record Created]
  Status: Pending (Orange)
  Severity: Low (Green) | Medium (Amber) | High (Orange) | Critical (Red)
  Timestamps: created_at, updated_at
  Spatial: location geography(POINT, 4326) with GiST index
  Audit Trail: IncidentAuditTrail (changed_at, old_status, new_status, internal_notes)
      │
      ▼
[Official Review & Action]
      │
      ├─ View details & resolution history (GET /api/v1/incidents/{id})
      ├─ Update status & priority (PATCH /api/v1/incidents/{id}/status)
      │    Status transitions: Pending ➔ In Progress ➔ Resolved (or Rejected)
      │    Add official resolution notes and update severity priority
      │    Appends chronological record to IncidentAuditTrail
      ▼
[Resolution Timeline]
  Available via GET /api/v1/incidents/{id}/history and rendered directly in Flutter's detail view.
```

---

## Safe & Useful AI Assistance

AquaFix implements **Responsible AI** principles designed to assist users and municipal inspectors without taking away human control:

1. **Advisory, Not Mandatory**: Gemini Vision output is treated strictly as an advisory recommendation. AI never makes final administrative decisions.
2. **Transparent Analysis Details**:
   - The user sees what information was analyzed: visual markers (e.g. *"pressurized water eruption"*, *"fractured concrete"*), confidence score, and explanatory reasoning.
   - The incident detail view preserves these AI insights for municipal officials.
3. **Manual Control & AI Bypass**:
   - Citizens can tap **"Analyze Photo"** to inspect AI suggestions before submitting.
   - Citizens can freely accept, edit, or override the suggested category and severity.
   - Citizens can toggle **"Submit without AI analysis"** to report issues entirely manually.
4. **Resilient & Fail-Safe**:
   - If the Gemini API is offline, experiencing quota limits, or unavailable, reports are **never rejected**. The system gracefully ingests the report with manual inputs and flags it for official human review.

---

## API Documentation

All API routes are versioned under `/api/v1`. Interactive OpenAPI documentation is accessible at `http://localhost:8000/docs`.

### Authentication Endpoints (`/api/v1/auth`)

| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| `POST` | `/api/v1/auth/register` | No (Rate limited: 5/min) | Register a new user (`citizen` or `official`). Requires email, password (≥6 chars), full name. |
| `POST` | `/api/v1/auth/login` | No (Rate limited: 10/min) | Authenticate with email & password; returns JWT bearer `access_token`. |
| `GET` | `/api/v1/auth/me` | Bearer Token | Retrieve currently authenticated user's profile and role. |
| `POST` | `/api/v1/auth/refresh` | Bearer Token | Refresh an active session and receive a new access token. |

### Incident Endpoints (`/api/v1/incidents`)

| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| `POST` | `/api/v1/incidents/analyze-image` | No (Rate limited: 15/min) | Advisory AI image preview. Returns suggested category, severity, confidence, reasoning, and visual markers without saving to DB. |
| `POST` | `/api/v1/incidents/report` | Optional | Ingest incident report (`multipart/form-data`: `file`, `latitude`, `longitude`, `description`, `category`, `severity`, `skip_ai`). |
| `GET` | `/api/v1/incidents/` | No | Public feed of incidents. Supports pagination (`skip`, `limit`) and filters: `status_filter`, `severity_filter`, radial `lat`, `lon`, `radius`. |
| `GET` | `/api/v1/incidents/{id}` | Bearer Token | Retrieve incident details with coordinates, timestamps, severity, and full resolution audit trail. |
| `PATCH` | `/api/v1/incidents/{id}/status` | Bearer Token (`official` role) | Update incident `status` and/or `severity` with `internal_notes`. Logs transition to `IncidentAuditTrail`. |
| `GET` | `/api/v1/incidents/{id}/history` | Bearer Token | Retrieve chronological audit trail and resolution history for an incident. |
| `DELETE` | `/api/v1/incidents/{id}` | Bearer Token (`official` role) | Delete incident record and cascade audit trail. |

### System Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check endpoint returning status and version. |
| `GET` | `/` | API root metadata and documentation links (`/docs`, `/openapi.json`). |

---

## Database Architecture & Setup

AquaFix uses PostgreSQL with the PostGIS extension for spatial analysis:

1. **PostgreSQL 13+ with PostGIS**:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
2. **Key Tables**:
   - `users`: Stores citizen and official accounts with native bcrypt-hashed passwords.
   - `incidents`: Stores reports with `location geography(POINT, 4326)` for metric distance calculations, severity levels, and AI suggestion metadata.
   - `incident_audit_trail`: Comprehensive audit log recording every status change, timestamps, modifier IDs, and official internal notes.
   - `applied_migrations`: Tracks applied schema migrations.
3. **Spatial Indexing**:
   - GiST index on `incidents.location` enables sub-millisecond geographic queries (`ST_DWithin`).
4. **Running Migrations**:
   ```bash
   cd backend
   python -m migrations.run_migrations
   ```

---

## Getting Started

### Prerequisites

- **Backend**: Python 3.8+ (tested on Python 3.11, 3.12, 3.14)
- **Database**: PostgreSQL 13+ with PostGIS extension (or in-memory SQLite for automated tests)
- **Frontend**: Flutter 3.x with Dart SDK

---

### Backend Setup

1. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure environment variables**:
   Create a `.env` file in `backend/` (or copy from `.env.example`):
   ```env
   PROJECT_NAME="AquaFix API"
   ENVIRONMENT="development"
   SECRET_KEY="dev-secret-key-change-in-production-use-openssl-rand-hex-32"
   ACCESS_TOKEN_EXPIRE_MINUTES=60

   # PostgreSQL with PostGIS extension
   DATABASE_URL="postgresql://postgres:postgres@localhost:5432/aquafix"

   # Google Gemini API Key (leave empty to use built-in Mock Vision service)
   GEMINI_API_KEY=""

   # Frontend URL for CORS
   FRONTEND_URL="http://localhost:3000"

   # Rate limiting
   RATE_LIMIT_PER_MINUTE=60
   ```

4. **Run migrations**:
   ```bash
   python -m migrations.run_migrations
   ```

5. **Start the API server**:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   *Alternatively:*
   ```bash
   python -m app.main
   ```
   The API will be available at `http://localhost:8000` with Swagger UI at `http://localhost:8000/docs`.

6. **Run Backend Test Suite**:
   ```bash
   pytest tests -v
   ```

---

### Frontend Setup

1. **Navigate to the frontend directory**:
   ```bash
   cd frontend
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Flutter Tests**:
   ```bash
   flutter test
   ```

4. **Run the Application**:
   ```bash
   flutter run
   ```

---

## Verification & Testing

AquaFix includes comprehensive unit, integration, and security test suites across both the API and client:

- **Backend Tests (37 passing tests)**:
  - Auth registration (citizen & official roles, validation, duplicate email rejection, password length constraints)
  - Auth login (valid credentials, invalid password, nonexistent user)
  - Profile retrieval & JWT token refresh
  - Incident reporting (file type validation, size limits, spatial coordinate validation)
  - Advisory AI analysis preview
  - Manual bypass (`skip_ai=true`) and offline AI fallback resilience
  - Public incident feed pagination and status/severity filtering
  - Incident detail retrieval with full resolution history
  - Role-based status updates (officials permitted, citizens forbidden with 403)
  - Audit trail logging and resolution history endpoint
  - Incident deletion permissions
- **Frontend Tests (12 passing tests)**:
  - IncidentModel JSON deserialization with severity and AI analysis
  - Severity display names, colors, and icons mapping
  - Status display names and color coding
  - IncidentAuditModel parsing
  - Coordinate, image extension, and file size validation

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
