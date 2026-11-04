-- AquaFix Migration 003: Add Full-Text Search GIN Index
-- Purpose: Accelerate full-text keyword searches across description and category
-- Date: November 4, 2026

CREATE INDEX IF NOT EXISTS idx_incidents_fts 
ON incidents USING GIN(to_tsvector('english', coalesce(description, '') || ' ' || category));
