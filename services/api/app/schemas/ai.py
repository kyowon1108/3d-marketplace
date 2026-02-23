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
