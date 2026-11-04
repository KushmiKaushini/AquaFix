import os
import io
import uuid
import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy.ext.compiler import compiles
from geoalchemy2 import Geography, Geometry
from fastapi.testclient import TestClient

# 1. Compile spatial types to TEXT for SQLite in-memory test runner
@compiles(Geography, "sqlite")
def compile_geography_sqlite(element, compiler, **kw):
    return "TEXT"

@compiles(Geometry, "sqlite")
def compile_geometry_sqlite(element, compiler, **kw):
    return "TEXT"

# Set dev environment variables before importing app
os.environ["SECRET_KEY"] = "test-secret-key-for-unit-and-integration-tests"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["ENVIRONMENT"] = "development"
os.environ["GEMINI_API_KEY"] = ""

from app.core.database import Base, get_db
from app.models.user import User
from app.models.incident import Incident
from app.models.audit import IncidentAuditTrail
from app.core.auth import hash_password, create_access_token
from app.main import app

# Create SQLite in-memory test engine with custom functions
test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

@event.listens_for(test_engine, "connect")
def register_sqlite_spatial_mocks(dbapi_con, con_record):
    dbapi_con.create_function("CreateSpatialIndex", 2, lambda a, b: 1)
    dbapi_con.create_function("CheckSpatialMetaData", 0, lambda: 1)
    dbapi_con.create_function("InitSpatialMetaData", 0, lambda: 1)
    dbapi_con.create_function("InitSpatialMetaData", 1, lambda a: 1)
    dbapi_con.create_function("RecoverGeometryColumn", 5, lambda *args: 1)
    dbapi_con.create_function("ST_GeogFromText", 1, lambda val: val)
    dbapi_con.create_function("AsBinary", 1, lambda val: b"dummy-binary")
    
    def parse_x(pt):
        try:
            return float(str(pt).split("(")[1].split(")")[0].split()[0])
        except Exception:
            return 79.8612

    def parse_y(pt):
        try:
            return float(str(pt).split("(")[1].split(")")[0].split()[1])
        except Exception:
            return 6.9271

    dbapi_con.create_function("ST_X", 1, parse_x)
    dbapi_con.create_function("ST_Y", 1, parse_y)
    dbapi_con.create_function("ST_DWithin", 3, lambda a, b, r: 1)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)

@pytest.fixture
def db_session():
    connection = test_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    # Disable rate limits during testing
    app.state.limiter.enabled = False

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.state.limiter.enabled = True

@pytest.fixture
def citizen_user(db_session):
    user = User(
        id=uuid.uuid4(),
        email="citizen@aquafix.org",
        hashed_password=hash_password("citizenpass123"),
        full_name="Jane Citizen",
        role="citizen",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def citizen_token(citizen_user):
    return create_access_token(
        data={"sub": str(citizen_user.id), "email": citizen_user.email, "role": citizen_user.role}
    )

@pytest.fixture
def citizen_headers(citizen_token):
    return {"Authorization": f"Bearer {citizen_token}"}

@pytest.fixture
def official_user(db_session):
    user = User(
        id=uuid.uuid4(),
        email="official@aquafix.org",
        hashed_password=hash_password("officialpass123"),
        full_name="Inspector Officer",
        role="official",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def official_token(official_user):
    return create_access_token(
        data={"sub": str(official_user.id), "email": official_user.email, "role": official_user.role}
    )

@pytest.fixture
def official_headers(official_token):
    return {"Authorization": f"Bearer {official_token}"}

@pytest.fixture
def dummy_image():
    """Generates a small dummy PNG byte payload for upload tests."""
    return io.BytesIO(
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
