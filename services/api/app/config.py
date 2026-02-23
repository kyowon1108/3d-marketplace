from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_env: str = "local"

    database_url: str = "postgresql://marketplace:marketplace@localhost:5433/marketplace"

    storage_backend: str = "local"
    storage_local_path: str = "./storage"
    storage_upload_signing_secret: str = ""
    storage_upload_ttl_seconds: int = 3600

    server_base_url: str = "http://localhost:8000"

    redis_url: str = "redis://localhost:6379/0"

    auth_provider: str = "dev"

    # Dev auth (must be explicitly enabled via env var)
    dev_auth_enabled: bool = False

    # CORS origins (comma-separated list, e.g. "https://beta.example.com,https://app.example.com")
    cors_origins: str = ""

    # JWT
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 30

    # Google OAuth
    google_client_id: str = ""
    google_client_secret: str = ""
    google_ios_client_id: str = ""

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()

if settings.storage_upload_ttl_seconds <= 0:
    raise ValueError("storage_upload_ttl_seconds must be a positive integer")

if settings.app_env != "local" and settings.dev_auth_enabled:
    raise ValueError("dev_auth_enabled must be false when app_env is not local")

if settings.app_env in {"beta", "production"}:
    if settings.jwt_secret_key == "change-me-in-production":
        raise ValueError(
            "jwt_secret_key must be changed from the default value in beta/production."
        )
    if len(settings.jwt_secret_key) < 32:
        raise ValueError("jwt_secret_key must be at least 32 characters in beta/production")

if settings.app_env != "local" and settings.storage_backend == "local":
    if len(settings.storage_upload_signing_secret) < 32:
        raise ValueError(
            "storage_upload_signing_secret must be at least 32 characters "
            "when local storage is used outside local environment"
        )
