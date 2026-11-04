# AquaFix — System Design & Architecture Specification

---

## 1. High-Level System Architecture

AquaFix is structured around a decoupled, mobile-first client and a spatial API gateway:

```mermaid
graph TD
    subgraph Client_Layer["Frontend Client (Flutter 3.x)"]
        UI["Mobile UI Screens (Auth, Feed, Report, Detail, Profile)"]
        State["Riverpod State Management (AppProviders)"]
        GPS["Geolocator GPS Service"]
        Storage["Flutter Secure Storage (JWT)"]
        MapEngine["FlutterMap (OpenStreetMap Integration)"]
        UI --> State
        UI --> GPS
        UI --> MapEngine
        State --> Storage
    end

    subgraph Gateway_Layer["API Gateway (FastAPI)"]
        CORS["CORS Middleware"]
        Limiter["SlowAPI Rate Limiter"]
        AuthMiddleware["JWT Authentication & RBAC Filter"]
        Routers["Versioned Routers (/api/v1/auth, /api/v1/incidents)"]
        CORS --> Limiter --> AuthMiddleware --> Routers
    end

    subgraph Service_Layer["Business Services"]
        GeminiService["Google Gemini 1.5 Flash Vision Service"]
        SpatialQueryEngine["PostGIS Spatial Query Engine"]
    end

    subgraph Persistence_Layer["Database (PostgreSQL 13+ with PostGIS)"]
        UsersTable[("users")]
        IncidentsTable[("incidents (geography point + GiST index)")]
        AuditTable[("incident_audit_trail")]
        MigrationsTable[("applied_migrations")]
    end

    State -->|"HTTPS / REST"| Gateway_Layer
    Routers --> GeminiService
    Routers --> SpatialQueryEngine
    SpatialQueryEngine --> Persistence_Layer
    Routers --> Persistence_Layer
```

---

## 2. Component Interaction & Sequence Flow

### 2.1 Incident Ingestion Flow with Advisory AI

```mermaid
sequenceDiagram
    autonumber
    actor Citizen as Citizen User
    participant App as Flutter Mobile App
    participant API as FastAPI Backend
    participant Gemini as Gemini 1.5 Flash
    participant DB as PostgreSQL + PostGIS

    Citizen->>App: Captures photo & taps "Get GPS"
    App->>App: Locks GPS coordinates (lat, lon)
    
    opt Advisory AI Preview
        Citizen->>App: Taps "Analyze Photo with AI"
        App->>API: POST /incidents/analyze-image (Multipart file)
        API->>Gemini: Multimodal prompt with image bytes
        Gemini-->>API: JSON diagnostic recommendation
        API-->>App: Category, severity, confidence, visual markers
        App->>Citizen: Displays advisory suggestion card
        Citizen->>App: Accepts or modifies category & severity
    end

    Citizen->>App: Taps "Submit Report"
    App->>API: POST /incidents/report (file, lat, lon, category, severity, skip_ai)
    API->>API: Validate file (<5MB, JPEG/PNG/WebP) & spatial bounds
    
    alt skip_ai is false
        API->>Gemini: Verify issue & extract features
        Gemini-->>API: Verified metadata
    else skip_ai is true
        API->>API: Mark as manual citizen verification
    end

    API->>DB: INSERT INTO incidents (location = ST_GeogFromText, severity, category, ...)
    API->>DB: INSERT INTO incident_audit_trail (status = 'Pending')
    DB-->>API: Incident created (UUID)
    API-->>App: 201 Created (IncidentResponse)
    App-->>Citizen: Shows confirmation banner & refreshes feed
```

### 2.2 Status Update & Resolution Flow

```mermaid
sequenceDiagram
    autonumber
    actor Official as Municipal Official
    participant App as Flutter Mobile App
    participant API as FastAPI Backend
    participant DB as PostgreSQL + PostGIS

    Official->>App: Opens incident detail view
    App->>API: GET /incidents/{id} (Bearer Token)
    API->>DB: Query Incident + ST_X/ST_Y + IncidentAuditTrail
    DB-->>API: Incident record with resolution history
    API-->>App: Incident details with timeline
    App-->>Official: Renders status, severity badge, map, and history

    Official->>App: Selects "Update Status" dialog
    Official->>App: Sets status to "In Progress", updates severity, adds notes
    App->>API: PATCH /incidents/{id}/status (Bearer Token)
    API->>API: Verify token role == 'official'
    API->>DB: UPDATE incidents SET status = 'In Progress', severity = 'High'
    API->>DB: INSERT INTO incident_audit_trail (old_status, new_status, notes, modified_by)
    DB-->>API: Updated record
    API-->>App: 200 OK (Updated IncidentResponse)
    App-->>Official: Refreshes view with new timeline step
```

---

## 3. Technology Evaluation & Decision Log

| Component | Selected Technology | Rationale |
| :--- | :--- | :--- |
| **Backend Framework** | FastAPI (Python) | High performance via ASGI/uvicorn, built-in OpenAPI documentation, native async support, and type safety with Pydantic. |
| **Spatial Engine** | PostGIS + GeoAlchemy2 | Standard spatial database engine providing metric spherical calculations (`geography`) and GiST spatial indexing for low-latency radial queries. |
| **Mobile Client** | Flutter | Cross-platform single codebase (iOS, Android, Web, Desktop) with 60fps native rendering, material design system, and declarative Riverpod state management. |
| **AI Ingestion** | Gemini 1.5 Flash Vision | Sub-second latency for multimodal image reasoning, low token cost, and structured JSON output capabilities. |
| **Password Security** | Native `bcrypt` | Standard salted key derivation function resilient against GPU-based offline dictionary attacks. |
