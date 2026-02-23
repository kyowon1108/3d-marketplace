import json
import logging

from openai import AsyncOpenAI

from app.config import settings

logger = logging.getLogger(__name__)

SUGGEST_PROMPT = """\
이 제품 사진을 보고 한국어 중고거래 마켓플레이스용 상품 등록 정보를 작성해주세요.

{dims_section}

JSON으로 응답해주세요:
- title: 15자 이내, 제품 종류 + 핵심 특징
- description: 3-5문장. 외관 상태, 용도 포함{dims_instruction}
"""


def _build_prompt(
    dims_width: float | None,
    dims_height: float | None,
    dims_depth: float | None,
    dims_source: str | None,
) -> str:
    if dims_width and dims_height and dims_depth:
        source_label = "LiDAR 정밀 측정" if dims_source == "ios_lidar" else "측정"
        dims_section = (
            f"측정 치수: {dims_width}cm × {dims_height}cm"
            f" × {dims_depth}cm ({source_label})"
        )
        dims_instruction = ". 치수 정보를 설명에 자연스럽게 포함"
    else:
        dims_section = "치수 정보: 없음"
        dims_instruction = ""

    return SUGGEST_PROMPT.format(dims_section=dims_section, dims_instruction=dims_instruction)


async def suggest_listing(
    thumbnail_url: str,
    dims_width: float | None = None,
    dims_height: float | None = None,
    dims_depth: float | None = None,
    dims_source: str | None = None,
) -> dict[str, str]:
    """Call OpenAI gpt-4o-mini Vision to generate a listing suggestion."""
    client = AsyncOpenAI(api_key=settings.openai_api_key)
    prompt = _build_prompt(dims_width, dims_height, dims_depth, dims_source)

    response = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": thumbnail_url}},
                ],
            }
        ],
        max_tokens=300,
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content or "{}"
    try:
        result = json.loads(content)
    except json.JSONDecodeError:
        logger.warning("AI response was not valid JSON: %s", content)
        result = {}

    return {
        "suggested_title": result.get("title", ""),
        "suggested_description": result.get("description", ""),
    }
