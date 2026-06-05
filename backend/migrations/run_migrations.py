"""
Database Migration Runner
Executes SQL migration scripts to set up database schema
"""

import os
import sys
import logging
from pathlib import Path
from sqlalchemy import text, create_engine
from sqlalchemy.exc import SQLAlchemyError

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.config import settings

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

MIGRATIONS_DIR = Path(__file__).parent
APPLIED_MIGRATIONS_TABLE = "applied_migrations"


def get_applied_migrations(connection):
    """Get list of migrations that have already been applied."""
    try:
        result = connection.execute(
            text(f"SELECT migration_name FROM {APPLIED_MIGRATIONS_TABLE} ORDER BY applied_at")
        )
        return [row[0] for row in result]
    except Exception:
        # Table doesn't exist yet
        return []


def create_migrations_table(connection):
    """Create the applied_migrations tracking table."""
    try:
        connection.execute(text(f"""
            CREATE TABLE IF NOT EXISTS {APPLIED_MIGRATIONS_TABLE} (
                id SERIAL PRIMARY KEY,
                migration_name VARCHAR(255) UNIQUE NOT NULL,
                applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        connection.commit()
        logger.info(f"✅ Created {APPLIED_MIGRATIONS_TABLE} table")
    except Exception as e:
        logger.error(f"❌ Failed to create migrations table: {str(e)}")
        raise


def record_migration(connection, migration_name):
    """Record that a migration has been applied."""
    try:
        connection.execute(
            text(f"INSERT INTO {APPLIED_MIGRATIONS_TABLE} (migration_name) VALUES (:name)"),
            {"name": migration_name}
        )
        connection.commit()
    except Exception as e:
        logger.error(f"❌ Failed to record migration: {str(e)}")
        raise


def run_migrations():
    """Discover and run all pending migrations."""
    logger.info("🔄 Starting database migrations...")
    
    # Connect to database
    try:
        engine = create_engine(settings.DATABASE_URL, echo=False)
        connection = engine.connect()
        logger.info("✅ Connected to database")
    except Exception as e:
        logger.error(f"❌ Failed to connect to database: {str(e)}")
        return False
    
    try:
        # Create migrations tracking table if needed
        create_migrations_table(connection)
        
        # Get list of applied migrations
        applied = get_applied_migrations(connection)
        logger.info(f"Already applied migrations: {applied if applied else 'None'}")
        
        # Find and run pending migrations
        migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith('.sql')])
        
        if not migration_files:
            logger.warning("⚠️ No migration files found")
            return True
        
        pending_migrations = [f for f in migration_files if f not in applied]
        
        if not pending_migrations:
            logger.info("✅ All migrations already applied")
            connection.close()
            return True
        
        logger.info(f"Found {len(pending_migrations)} pending migration(s): {pending_migrations}")
        
        # Execute each pending migration
        for migration_file in pending_migrations:
            migration_path = os.path.join(MIGRATIONS_DIR, migration_file)
            
            logger.info(f"🔄 Running migration: {migration_file}")
            
            try:
                with open(migration_path, 'r') as f:
                    sql_content = f.read()
                
                # Split by statements and execute non-empty ones
                statements = [s.strip() for s in sql_content.split(';') if s.strip()]
                
                for i, statement in enumerate(statements, 1):
                    # Skip comments and empty lines
                    if statement.startswith('--') or not statement:
                        continue
                    
                    try:
                        connection.execute(text(statement))
                        connection.commit()
                        logger.debug(f"  ✓ Executed statement {i}")
                    except Exception as e:
                        # Some statements might fail if they already exist (e.g., CREATE INDEX IF NOT EXISTS)
                        if 'already exists' in str(e).lower() or 'duplicate' in str(e).lower():
                            logger.debug(f"  ⚠️ Statement {i} already applied: {str(e)[:100]}")
                        else:
                            logger.error(f"  ❌ Failed at statement {i}: {str(e)[:200]}")
                            raise
                
                # Record successful migration
                record_migration(connection, migration_file)
                logger.info(f"✅ Successfully applied migration: {migration_file}")
                
            except Exception as e:
                logger.error(f"❌ Migration {migration_file} failed: {str(e)}")
                connection.close()
                return False
        
        connection.close()
        logger.info("✅ All pending migrations completed successfully")
        return True
        
    except Exception as e:
        logger.error(f"❌ Migration process failed: {str(e)}")
        connection.close()
        return False


if __name__ == "__main__":
    success = run_migrations()
    sys.exit(0 if success else 1)
