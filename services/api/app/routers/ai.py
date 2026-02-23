from fastapi import APIRouter, Depends, HTTPException

from app.config import settings
from app.middleware.auth import get_current_user
from app.models.user import User
from app.schemas.ai import AISuggestListingRequest, AISuggestListingResponse
from app.services.ai_suggest_service import suggest_listing

router = APIRouter(prefix="/v1/ai", tags=["ai"])


@router.post("/suggest-listing", response_model=AISuggestListingResponse)
async def ai_suggest_listing(
    body: AISuggestListingRequest,
    user: User = Depends(get_current_user),
) -> AISuggestListingResponse:
    if not settings.openai_api_key:
        raise HTTPException(
            status_code=503,
            detail="AI suggestion service is not configured",
        )

    try:
        result = await suggest_listing(
            thumbnail_url=body.thumbnail_url,
            dims_width=body.dims_width,
            dims_height=body.dims_height,
            dims_depth=body.dims_depth,
            dims_source=body.dims_source,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"AI service error: {exc}",
        )

    return AISuggestListingResponse(**result)
