import base64
import json
import logging
import time
from typing import Any

from openai import AsyncOpenAI

from app.config import settings
from app.models.enums import ProductCategory, ProductCondition

logger = logging.getLogger(__name__)

_VALID_CATEGORIES = {e.value for e in ProductCategory}
_VALID_CONDITIONS = {e.value for e in ProductCondition}

# Cache key type: (thumbnail_url, dims_width, dims_height, dims_depth, dims_source)
_CacheKey = tuple[str, float | None, float | None, float | None, str | None]
# In-memory TTL cache: {cache_key: (result_dict, expire_timestamp)}
_cache: dict[_CacheKey, tuple[dict[str, Any], float]] = {}
_CACHE_TTL = 300  # 5 minutes

SUGGEST_PROMPT = """\
사진 속 제품이 무엇인지 파악하고, 한국어 중고거래 마켓플레이스 상품 등록 정보를 작성해주세요.
사진을 주의 깊게 관찰하여 제품의 종류, 브랜드, 모델명을 최대한 정확히 식별해주세요.

{dims_section}

아래 JSON 형식으로 응답해주세요:
- title: 15자 이내, 제품명 + 핵심 특징 (예: "로지텍 MX Master 3 마우스")
- description: 3-5문장. 제품명, 외관 상태, 용도 포함. 치수는 별도 표시되므로 설명에 넣지 마세요
- category: 다음 중 하나 — ELECTRONICS, FURNITURE, CLOTHING, BOOKS_MEDIA, \
SPORTS, LIVING, BEAUTY, HOBBY, OTHER
- condition: 다음 중 하나 — NEW, LIKE_NEW, USED, WORN (사진 상태 기반 추정)
- price_min: 한국 중고시장 기준 최저 추정가 (KRW 정수)
- price_max: 한국 중고시장 기준 최고 추정가 (KRW 정수)
- price_reason: 가격 추정 근거 1문장{comparison_instruction}
"""


def _build_prompt(
    dims_width: float | None,
    dims_height: float | None,
    dims_depth: float | None,
    dims_source: str | None,
) -> str:
    if dims_width and dims_height and dims_depth:
        source_note = "스캐너로 자동 측정된 값" if dims_source == "ios_lidar" else "측정값"
        dims_section = (
            f"참고 - 이 제품의 실측 크기: 가로 {dims_width}cm × 세로 {dims_height}cm"
            f" × 높이 {dims_depth}cm ({source_note})"
        )
        dims_instruction = ""
        comparison_instruction = (
            "\n- dims_comparison: 크기를 일상 물건과 비교하는 짧은 문구 "
            "(예: '손바닥보다 약간 큰 크기')"
        )
    else:
        dims_section = "치수 정보: 없음"
        dims_instruction = ""
        comparison_instruction = ""

    return SUGGEST_PROMPT.format(
        dims_section=dims_section,
        dims_instruction=dims_instruction,
        comparison_instruction=comparison_instruction,
    )


def _normalize_category(raw: str | None) -> str | None:
    if not raw:
        return None
    val = raw.strip().upper()
    return val if val in _VALID_CATEGORIES else None


def _normalize_condition(raw: str | None) -> str | None:
    if not raw:
        return None
    val = raw.strip().upper()
    return val if val in _VALID_CONDITIONS else None


def _normalize_price(val: int | float | str | None) -> int | None:
    if val is None:
        return None
    try:
        price = int(val)
        return price if price > 0 else None
    except (ValueError, TypeError):
        return None


def _evict_expired() -> None:
    now = time.monotonic()
    expired = [k for k, (_, exp) in _cache.items() if now > exp]
    for k in expired:
        del _cache[k]


def _resolve_thumbnail_url(thumbnail_url: str) -> str:
    """Convert local storage URL to base64 data URL for OpenAI accessibility."""
    if settings.storage_backend != "local":
        return thumbnail_url

    # Detect local storage URL by path pattern
    storage_marker = "/storage/assets/"
    idx = thumbnail_url.find(storage_marker)
    if idx == -1:
        return thumbnail_url

    # Extract storage key (strip query params)
    storage_key = thumbnail_url[idx + len("/storage/"):].split("?")[0]

    from app.services.storage_service import StorageService

    storage = StorageService()
    try:
        file_path = storage.resolve_safe_path(storage_key)
    except ValueError:
        logger.warning("ai_suggest_local_resolve_failed", extra={"key": storage_key})
        return thumbnail_url

    # If exact path not found, search for any image in the asset directory
    if not file_path.exists():
        parent = file_path.parent
        if parent.exists():
            for candidate in sorted(parent.iterdir()):
                if candidate.suffix.lower() in {".png", ".jpg", ".jpeg"}:
                    file_path = candidate
                    break
            else:
                return thumbnail_url
        else:
            return thumbnail_url

    data = file_path.read_bytes()
    # Detect MIME from file magic bytes, not extension (iOS saves JPEG as .png)
    if data[:2] == b"\xff\xd8":
        mime = "image/jpeg"
    elif data[:8] == b"\x89PNG\r\n\x1a\n":
        mime = "image/png"
    else:
        mime = "image/png"
    b64 = base64.b64encode(data).decode("utf-8")
    logger.info("ai_suggest_local_thumbnail_resolved", extra={"path": str(file_path)})
    return f"data:{mime};base64,{b64}"


async def suggest_listing(
    thumbnail_url: str,
    dims_width: float | None = None,
    dims_height: float | None = None,
    dims_depth: float | None = None,
    dims_source: str | None = None,
) -> dict[str, Any]:
    """Call OpenAI gpt-4o-mini Vision to generate a listing suggestion."""
    # Check cache (key includes dims to avoid stale results)
    cache_key: _CacheKey = (thumbnail_url, dims_width, dims_height, dims_depth, dims_source)
    _evict_expired()
    cached = _cache.get(cache_key)
    if cached is not None:
        logger.info("ai_suggest_cache_hit", extra={"thumbnail_url": thumbnail_url})
        return cached[0]

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    prompt = _build_prompt(dims_width, dims_height, dims_depth, dims_source)

    # Resolve local storage URLs to base64 data URLs for OpenAI accessibility
    image_url = _resolve_thumbnail_url(thumbnail_url)

    response = await client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": image_url}},
                ],
            }
        ],
        max_tokens=600,
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content or "{}"
    try:
        result = json.loads(content)
    except json.JSONDecodeError:
        logger.warning("ai_suggest_parse_error", extra={"raw_content": content})
        result = {}

    # Normalize and validate
    category = _normalize_category(result.get("category"))
    condition = _normalize_condition(result.get("condition"))
    price_min = _normalize_price(result.get("price_min"))
    price_max = _normalize_price(result.get("price_max"))

    # Ensure min <= max
    if price_min is not None and price_max is not None and price_min > price_max:
        price_min, price_max = price_max, price_min

    parsed = {
        "suggested_title": result.get("title", ""),
        "suggested_description": result.get("description", ""),
        "suggested_category": category,
        "suggested_condition": condition,
        "suggested_price_min": price_min,
        "suggested_price_max": price_max,
        "dims_comparison": result.get("dims_comparison") or None,
        "suggested_price_reason": result.get("price_reason") or None,
    }

    logger.info(
        "ai_suggest_result",
        extra={
            "has_title": bool(parsed["suggested_title"]),
            "has_description": bool(parsed["suggested_description"]),
            "category": category,
            "condition": condition,
            "has_price": price_min is not None,
            "has_dims_comparison": parsed["dims_comparison"] is not None,
        },
    )

    # Store in cache
    _cache[cache_key] = (parsed, time.monotonic() + _CACHE_TTL)

    return parsed
