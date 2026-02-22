from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_env: str = "local"
    secret_key: str = "change-me-in-production"

    database_url: str = "postgresql://marketplace:marketplace@localhost:5433/marketplace"

    storage_backend: str = "local"
    storage_local_path: str = "./storage"

    redis_url: str = "redis://localhost:6379/0"

    auth_provider: str = "dev"

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
