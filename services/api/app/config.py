from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_env: str = "local"
    secret_key: str = "change-me-in-production"

    database_url: str = "postgresql://marketplace:marketplace@localhost:5433/marketplace"

    storage_backend: str = "local"
    storage_local_path: str = "./storage"

    server_base_url: str = "http://localhost:8000"

    redis_url: str = "redis://localhost:6379/0"

    auth_provider: str = "dev"

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
