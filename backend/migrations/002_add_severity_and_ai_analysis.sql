-- AquaFix Migration 002: Add Severity and AI Analysis Columns
-- Purpose: Support incident lifecycle severity tracking and transparent AI suggestion records
-- Date: November 4, 2026

-- Add severity column with default 'Medium'
ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS severity VARCHAR(20) DEFAULT 'Medium' NOT NULL;

-- Add ai_analysis JSON column
ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS ai_analysis JSONB DEFAULT NULL;

-- Index on severity for filtering queries
CREATE INDEX IF NOT EXISTS idx_incidents_severity
ON incidents(severity);

-- Check constraint for valid severity levels
ALTER TABLE incidents
ADD CONSTRAINT chk_incident_severity
CHECK (severity IN ('Low', 'Medium', 'High', 'Critical'));
