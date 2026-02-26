from pydantic import BaseModel


class AISuggestListingRequest(BaseModel):
    thumbnail_url: str
    dims_width: float | None = None
    dims_height: float | None = None
    dims_depth: float | None = None
    dims_source: str | None = None


class AISuggestListingResponse(BaseModel):
    suggested_title: str
    suggested_description: str
    suggested_category: str | None = None
    suggested_condition: str | None = None
    suggested_price_min: int | None = None
    suggested_price_max: int | None = None
    dims_comparison: str | None = None
    suggested_price_reason: str | None = None
