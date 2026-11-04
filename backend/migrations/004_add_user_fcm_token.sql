-- AquaFix Migration: 004_add_user_fcm_token.sql
-- Description: Adds fcm_token column to users table for real-time push notifications on status updates.

ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(512);

-- Index fcm_token for lookup operations
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users (fcm_token) WHERE fcm_token IS NOT NULL;
