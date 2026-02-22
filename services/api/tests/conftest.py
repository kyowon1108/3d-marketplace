from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.database import get_db
from app.main import app
from app.models import Base
from app.models.user import User

# Use the same DB but with a test schema approach:
# We create/drop all tables for each test session.
TEST_DB_URL = settings.database_url
engine = create_engine(TEST_DB_URL)
TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


@pytest.fixture(scope="session", autouse=True)
def setup_database() -> Generator[None, None, None]:
    # Create any tables missing from the DB (idempotent for existing tables).
    Base.metadata.create_all(bind=engine)
    yield
    # Don't drop tables — preserve Alembic-managed schema


@pytest.fixture()
def db() -> Generator[Session, None, None]:
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        # Clean all data between tests
        for table in reversed(Base.metadata.sorted_tables):
            session.execute(text(f"TRUNCATE TABLE {table.name} CASCADE"))
        session.commit()
        session.close()


@pytest.fixture()
def client(db: Session) -> TestClient:
    def override_get_db() -> Generator[Session, None, None]:
        yield db

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture()
def test_user(db: Session) -> User:
    user = User(email="test@example.com", name="Test User", provider="dev")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def auth_headers(test_user: User) -> dict[str, str]:
    return {"Authorization": f"Bearer {test_user.id}"}
