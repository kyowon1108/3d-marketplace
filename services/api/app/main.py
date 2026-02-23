from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal
from app.routers import auth, chat, model_assets, products, storage, uploads


def _resolve_cors_origins() -> list[str]:
    """Determine CORS allowed origins from settings."""
    if settings.cors_origins:
        return [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
    if settings.app_env == "local":
        return ["*"]
    return []


def create_app() -> FastAPI:
    application = FastAPI(
        title="3D Marketplace API",
        version="0.1.0",
        docs_url="/docs" if settings.app_env != "production" else None,
    )

    application.add_middleware(
        CORSMiddleware,
        allow_origins=_resolve_cors_origins(),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Register routers
    application.include_router(uploads.router)
    application.include_router(model_assets.router)
    application.include_router(products.router)
    application.include_router(chat.router)
    application.include_router(auth.router)
    application.include_router(storage.router)

    @application.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @application.get("/readyz")
    def readyz() -> JSONResponse:
        try:
            db = SessionLocal()
            try:
                db.execute(text("SELECT 1"))
            finally:
                db.close()
        except Exception:
            return JSONResponse(status_code=503, content={"status": "unavailable"})
        return JSONResponse(status_code=200, content={"status": "ok"})

    return application


app = create_app()
