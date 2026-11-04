# AquaFix — Incident Lifecycle Report

**Document Date:** November 4, 2026  
**Status:** Complete Implementation  
**Audience:** System Architects, Municipal Operators, Full-Stack Engineers  

---

## 1. Domain Lifecycle Overview

The AquaFix incident lifecycle governs the complete trajectory of a civic infrastructure or water-sanitation issue—from the moment a citizen captures a photo on the mobile client through triage, field assessment, priority assignment, repair, and final resolution.

```mermaid
stateDiagram-v2
    [*] --> Ingestion: Citizen captures photo & GPS

    state Ingestion {
        [*] --> AI_Advisory_Preview: Optional "Analyze Photo"
        AI_Advisory_Preview --> Form_Review: Visual cues, confidence & suggestions
        Form_Review --> Manual_Override: User edits category & severity
        Form_Review --> Direct_Submit: User accepts suggestions
        [*] --> Direct_Submit: User skips AI (skip_ai=true)
    }

    Ingestion --> Pending: POST /api/v1/incidents/report
    note right of Pending: Audit log: "Incident reported by citizen"

    Pending --> In_Progress: Official dispatches repair crew (PATCH /status)
    note right of In_Progress: Audit log: "Crew dispatched to address issue"

    In_Progress --> Resolved: Field repairs completed (PATCH /status)
    note right of Resolved: Audit log: "Pipe repaired & pressure verified"

    Pending --> Rejected: Spam, duplicate, or out of municipal jurisdiction
    In_Progress --> Rejected: Deemed non-actionable upon field inspection

    Resolved --> [*]
    Rejected --> [*]
```

---

## 2. Five Pillars of Lifecycle Consistency

### 2.1 Status Consistency
- **Allowed States:** `Pending`, `In Progress`, `Resolved`, `Rejected`.
- **Database:** Enforced in SQL check constraint `chk_incident_status` and model `Incident.status`.
- **API:** Validated via Pydantic schema `VALID_STATUSES` on create, query, and status update.
- **Flutter Client:** Typed enum `IncidentStatus` with unified color coding:
  - `Pending`: Amber (`#F59E0B`)
  - `In Progress`: Blue (`#3B82F6`)
  - `Resolved`: Emerald (`#10B981`)
  - `Rejected`: Crimson (`#EF4444`)

### 2.2 Severity Priority
- **Allowed Priorities:** `Low`, `Medium`, `High`, `Critical`.
- **Database:** Enforced in SQL check constraint `chk_incident_severity` and model `Incident.severity`.
- **API:** Supported on incident ingestion, official status patch, and query filtering (`?severity_filter=Critical`).
- **Flutter Client:**
  - Citizen report form: Interactive `ChoiceChip` priority selector.
  - Incident list: Priority badge displayed on each incident card.
  - Incident detail: Prominent severity badge with distinct icons and colors:
    - `Critical`: Dark Red (`#DC2626`)
    - `High`: Deep Orange (`#EA580C`)
    - `Medium`: Amber (`#F59E0B`)
    - `Low`: Emerald (`#10B981`)
  - Status Update Dialog: Officials can adjust priority level as conditions change in the field.

### 2.3 Timestamps
- `created_at`: Set automatically via database server default (`func.now()`).
- `updated_at`: Updated on every mutation via `onupdate=func.now()`.
- `changed_at`: Timestamp on each `IncidentAuditTrail` record documenting the exact second a status or priority changed.
- Formatting: Serialized as ISO 8601 strings and rendered in local client time (e.g. `04/11/2026 at 18:30`).

### 2.4 Location & PostGIS Geography
- **Input:** GPS hardware coordinates via Flutter `geolocator` plugin (validated: $-90 \leq \text{lat} \leq 90$, $-180 \leq \text{lon} \leq 180$).
- **Database:** Stored as `geography(POINT, 4326)` in PostGIS.
- **Mapping:** Visualized with an interactive OpenStreetMap marker in Flutter `IncidentDetailScreen` using `flutter_map` and `latlong2`.

### 2.5 Resolution History & Audit Trail
- **Audit Table:** `incident_audit_trail` records:
  - `id`: UUID primary key
  - `incident_id`: Foreign key cascading on delete
  - `modified_by`: Foreign key to `users.id` (set null on delete)
  - `old_status`: Previous status string
  - `new_status`: New status string
  - `internal_notes`: Official description of actions taken
  - `changed_at`: Modification timestamp
- **Endpoint:** `GET /api/v1/incidents/{incident_id}/history` returns the complete chronological timeline.
- **Client Presentation:** The mobile app renders an interactive resolution timeline showing each state change, the official author, internal work notes, and date/time.

---

## 3. End-to-End Traceability Matrix

| Lifecycle Field | Flutter Form Input | API Request / Validation | PostgreSQL Column / Type | Audit Log Entry | Flutter Detail View |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Status** | Starts at `Pending` | `VALID_STATUSES` check | `status VARCHAR(50)` | `old_status` / `new_status` | Interactive Status Badge |
| **Severity** | ChoiceChip selector | `VALID_SEVERITIES` check | `severity VARCHAR(20)` | Recorded in `internal_notes` | Priority Badge & Icon |
| **Category** | Dropdown / AI suggestion | `VALID_CATEGORIES` check | `category VARCHAR(100)` | Recorded in initial audit note | Category Title |
| **Coordinates** | GPS lock (`geolocator`) | $-90..90$, $-180..180$ check | `location geography(POINT, 4326)` | Coordinates indexed with GiST | Coordinates chip + OpenStreetMap |
| **Photo Upload** | Camera or Gallery | MIME + size ($\le 5\text{MB}$) check | `image_url VARCHAR(512)` | Image preserved on disk | Image preview widget |
| **Resolution Notes**| Status dialog notes | String ($\le 500$ chars) | N/A (Stored in Audit) | `internal_notes TEXT` | Chronological Timeline |
| **Modifier** | Auth token session | JWT sub claim verification | `users.id UUID` | `modified_by UUID` | "By: Inspector Name" label |
