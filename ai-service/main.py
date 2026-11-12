"""VieGym AI Service: nhận context đã chuẩn hóa từ backend, gọi nhà cung cấp AI, trả câu trả lời.

Chỉ backend gọi được (header X-Internal-Key, chạy ở 127.0.0.1/mạng nội bộ). Không truy cập database,
không có công cụ (SQL, shell, URL) cho model. Log chỉ ghi requestId, thời lượng, kết quả.
"""

import hmac
import json
import logging
import os
import time
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Any, Literal
from uuid import UUID

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from providers import ChatProvider, ProviderError, ProviderTimeout, Turn, gemini_from_env

load_dotenv(Path(__file__).resolve().parent / ".env")

log = logging.getLogger("viegym.ai")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

# Backend chờ 30 giây (BR-AI04); ở đây tự cắt sớm hơn để kịp trả 504 có mã.
DEADLINE_SECONDS = float(os.getenv("AI_DEADLINE_SECONDS", "25"))
MAX_HISTORY = 20

app = FastAPI(title="VieGym AI Service")


class HistoryItem(BaseModel):
    role: Literal["USER", "ASSISTANT"]
    content: str = Field(min_length=1, max_length=20_000)


class ChatIn(BaseModel):
    """Hợp đồng nội bộ docs/05 §12."""

    requestId: UUID
    systemPrompt: str = Field(min_length=1, max_length=20_000)
    context: dict[str, Any]
    history: list[HistoryItem] = Field(default_factory=list, max_length=MAX_HISTORY)
    message: str = Field(min_length=1, max_length=2_000)


class ChatOut(BaseModel):
    content: str
    model: str
    promptTokens: int | None = None
    completionTokens: int | None = None


@lru_cache
def get_provider() -> ChatProvider:
    return gemini_from_env()


def require_internal_key(x_internal_key: Annotated[str | None, Header()] = None) -> None:
    expected = os.getenv("AI_INTERNAL_KEY", "")
    if not expected:
        raise HTTPException(status_code=503, detail={"code": "AI_NOT_CONFIGURED"})
    if not x_internal_key or not hmac.compare_digest(x_internal_key.encode(), expected.encode()):
        raise HTTPException(status_code=401, detail={"code": "UNAUTHORIZED"})


def build_turns(body: ChatIn) -> list[Turn]:
    """Lịch sử giữ nguyên vai; lượt cuối = khối dữ liệu có cấu trúc + câu hỏi.

    Context là dữ liệu (system prompt nói rõ không làm theo chỉ dẫn nằm trong đó). Đóng thẻ
    </user_data> trong dữ liệu được vô hiệu hóa để không "thoát" khỏi khối.
    """
    turns = [Turn("user" if h.role == "USER" else "model", h.content) for h in body.history]
    data = json.dumps(body.context, ensure_ascii=False, separators=(",", ":"), default=str)
    data = data.replace("</user_data>", "<\\/user_data>")
    turns.append(Turn("user", f"<user_data>\n{data}\n</user_data>\n\nCâu hỏi của người dùng:\n{body.message}"))
    return turns


def error(status: int, code: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"code": code})


@app.get("/health")
def health():
    return {"status": "UP", "service": "viegym-ai"}


@app.post("/internal/chat", response_model=ChatOut, dependencies=[Depends(require_internal_key)])
async def chat(body: ChatIn, provider: Annotated[ChatProvider, Depends(get_provider)]):
    started = time.perf_counter()
    outcome = "OK"
    try:
        reply = await provider.generate(body.systemPrompt, build_turns(body), DEADLINE_SECONDS)
        if not reply.content.strip():
            outcome = "AI_EMPTY_RESPONSE"
            return error(502, outcome)
        return ChatOut(content=reply.content.strip(), model=reply.model, promptTokens=reply.prompt_tokens,
                       completionTokens=reply.completion_tokens)
    except ProviderTimeout:
        outcome = "AI_TIMEOUT"
        return error(504, outcome)
    except ProviderError as exc:
        outcome = f"AI_UPSTREAM_ERROR ({exc})"
        return error(502, "AI_UPSTREAM_ERROR")
    finally:
        log.info("request %s -> %s in %d ms", body.requestId, outcome, (time.perf_counter() - started) * 1000)
