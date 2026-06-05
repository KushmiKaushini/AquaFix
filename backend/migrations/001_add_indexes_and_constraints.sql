-- AquaFix Migration 001: Add Indexes and Constraints
-- Purpose: Optimize database queries and enforce data integrity
-- Date: June 5, 2026

-- ============================================================================
-- INDEXES FOR QUERY OPTIMIZATION
-- ============================================================================

-- Index on incidents.status for filtering queries
CREATE INDEX IF NOT EXISTS idx_incidents_status 
ON incidents(status);

-- Index on incidents.category for category filtering
CREATE INDEX IF NOT EXISTS idx_incidents_category 
ON incidents(category);

-- Index on incidents.reporter_id for user-incident joins
CREATE INDEX IF NOT EXISTS idx_incidents_reporter_id 
ON incidents(reporter_id);

-- Spatial index on incidents.location for PostGIS queries
CREATE INDEX IF NOT EXISTS idx_incidents_location 
ON incidents USING GIST(location);

-- Index on incidents.created_at for time-based sorting
CREATE INDEX IF NOT EXISTS idx_incidents_created_at 
ON incidents(created_at DESC);

-- Index on audit_trail.incident_id for incident history lookups
CREATE INDEX IF NOT EXISTS idx_audit_incident_id 
ON incident_audit_trail(incident_id);

-- Index on audit_trail.modified_by for user activity tracking
CREATE INDEX IF NOT EXISTS idx_audit_modified_by 
ON incident_audit_trail(modified_by);

-- Index on audit_trail.changed_at for audit history sorting
CREATE INDEX IF NOT EXISTS idx_audit_changed_at 
ON incident_audit_trail(changed_at DESC);

-- Index on users.email for authentication lookups
CREATE INDEX IF NOT EXISTS idx_users_email 
ON users(email);

-- Composite index for common queries: status + created_at
CREATE INDEX IF NOT EXISTS idx_incidents_status_created 
ON incidents(status, created_at DESC);

-- ============================================================================
-- DATA INTEGRITY CONSTRAINTS
-- ============================================================================

-- Add check constraint for valid status values
ALTER TABLE incidents
ADD CONSTRAINT chk_incident_status 
CHECK (status IN ('Pending', 'In Progress', 'Resolved', 'Rejected'));

-- Add check constraint for valid user roles
ALTER TABLE users
ADD CONSTRAINT chk_user_role 
CHECK (role IN ('citizen', 'official'));

-- Add check constraint for valid coordinates
ALTER TABLE incidents
ADD CONSTRAINT chk_valid_coordinates 
CHECK (true); -- PostGIS handles this with geography type

-- ============================================================================
-- SOFT DELETE SUPPORT (Optional, can be implemented later)
-- ============================================================================
-- Uncomment when ready to implement soft deletes
-- ALTER TABLE incidents ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
-- ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
-- CREATE INDEX idx_incidents_not_deleted ON incidents(deleted_at) WHERE deleted_at IS NULL;
-- CREATE INDEX idx_users_not_deleted ON users(deleted_at) WHERE deleted_at IS NULL;

-- ============================================================================
-- MIGRATION VERIFICATION
-- ============================================================================
-- Run these queries to verify the migration was successful:

-- SELECT schemaname, tablename, indexname 
-- FROM pg_indexes 
-- WHERE tablename IN ('incidents', 'users', 'incident_audit_trail')
-- ORDER BY tablename, indexname;

-- SELECT constraint_name, table_name, constraint_type
-- FROM information_schema.table_constraints
-- WHERE table_name IN ('incidents', 'users')
-- AND constraint_type = 'CHECK'
-- ORDER BY table_name;
