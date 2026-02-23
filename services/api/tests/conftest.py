import os
from collections.abc import Generator
from pathlib import Path

import pytest
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session, sessionmaker

from alembic import command

# Enable dev auth for tests (must be set before importing settings)
os.environ.setdefault("DEV_AUTH_ENABLED", "true")
TEST_DB_URL = os.getenv("TEST_DATABASE_URL")
if not TEST_DB_URL:
    raise RuntimeError("TEST_DATABASE_URL is required for test execution")

test_db_name = make_url(TEST_DB_URL).database or ""
if not test_db_name.endswith("_test"):
    raise RuntimeError(
        "TEST_DATABASE_URL must point to a dedicated test DB ending with '_test'"
    )

os.environ["DATABASE_URL"] = TEST_DB_URL

engine = create_engine(TEST_DB_URL)
TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


@pytest.fixture(scope="session", autouse=True)
def setup_database() -> Generator[None, None, None]:
    alembic_cfg = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    alembic_cfg.set_main_option("sqlalchemy.url", TEST_DB_URL)
    command.upgrade(alembic_cfg, "head")
    yield


@pytest.fixture()
def db() -> Generator[Session, None, None]:
    from app.models import Base

    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        # Clean all data between tests
        for table in reversed(Base.metadata.sorted_tables):
            session.execute(text(f'TRUNCATE TABLE "{table.name}" CASCADE'))
        session.commit()
        session.close()


@pytest.fixture()
def client(db: Session) -> Generator[TestClient, None, None]:
    from app.database import get_db
    from app.main import app

    def override_get_db() -> Generator[Session, None, None]:
        yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def test_user(db: Session):
    from app.models.user import User

    user = User(email="test@example.com", name="Test User", provider="dev")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def auth_headers(test_user) -> dict[str, str]:
    return {"Authorization": f"Bearer {test_user.id}"}
