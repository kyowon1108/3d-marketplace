from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import auth, chat, model_assets, products, storage, uploads


def create_app() -> FastAPI:
    application = FastAPI(
        title="3D Marketplace API",
        version="0.1.0",
        docs_url="/docs" if settings.app_env != "production" else None,
    )

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if settings.app_env == "local" else [],
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
    def readyz() -> dict[str, str]:
        return {"status": "ok"}

    return application


app = create_app()
