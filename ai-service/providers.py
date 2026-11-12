"""Adapter nhà cung cấp AI. Backend không biết provider nào; đổi provider chỉ sửa file này."""

import asyncio
import os
from dataclasses import dataclass
from typing import Protocol

import httpx
from google import genai
from google.genai import errors, types


@dataclass(frozen=True)
class Turn:
    """Một lượt hội thoại đã chuẩn hóa: role 'user' hoặc 'model'."""

    role: str
    text: str


@dataclass(frozen=True)
class ProviderReply:
    content: str
    model: str
    prompt_tokens: int | None = None
    completion_tokens: int | None = None


class ProviderTimeout(Exception):
    """Quá deadline nội bộ."""


class ProviderError(Exception):
    """Lỗi nhà cung cấp (429, 5xx, cấu hình, mạng). Không mang nội dung lỗi gốc ra ngoài."""


class ChatProvider(Protocol):
    async def generate(self, system: str, turns: list[Turn], deadline_seconds: float) -> ProviderReply: ...


class GeminiProvider:
    """Gemini qua SDK google-genai (cấu hình GEMINI_API_KEY, GEMINI_MODEL trong .env)."""

    def __init__(self, api_key: str, model: str, max_output_tokens: int):
        self._model = model
        self._max_output_tokens = max_output_tokens
        self._client = genai.Client(api_key=api_key) if api_key else None

    async def generate(self, system: str, turns: list[Turn], deadline_seconds: float) -> ProviderReply:
        if self._client is None or not self._model:
            raise ProviderError("missing provider configuration")
        contents = [types.Content(role=t.role, parts=[types.Part(text=t.text)]) for t in turns]
        config = types.GenerateContentConfig(
            system_instruction=system,
            max_output_tokens=self._max_output_tokens,
            temperature=0.4,
        )
        try:
            response = await asyncio.wait_for(
                self._client.aio.models.generate_content(model=self._model, contents=contents, config=config),
                timeout=deadline_seconds,
            )
        except (asyncio.TimeoutError, httpx.TimeoutException) as exc:
            raise ProviderTimeout() from exc
        except (errors.APIError, httpx.HTTPError) as exc:
            raise ProviderError(type(exc).__name__) from exc

        try:
            text = (response.text or "").strip()
        except ValueError:
            # Bị chặn bởi bộ lọc an toàn: không có phần văn bản.
            text = ""
        usage = response.usage_metadata
        return ProviderReply(
            content=text,
            model=response.model_version or self._model,
            prompt_tokens=usage.prompt_token_count if usage else None,
            completion_tokens=usage.candidates_token_count if usage else None,
        )


def gemini_from_env() -> GeminiProvider:
    return GeminiProvider(
        api_key=os.getenv("GEMINI_API_KEY", "").strip(),
        model=os.getenv("GEMINI_MODEL", "").strip(),
        max_output_tokens=int(os.getenv("AI_MAX_OUTPUT_TOKENS", "2048")),
    )
