import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from google.genai import types


def main():
    env_path = Path(__file__).resolve().parent / ".env"
    load_dotenv(env_path)

    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    model = os.getenv("GEMINI_MODEL", "").strip()

    if not api_key or not model:
        print("THIEU CAU HINH: Kiem tra GEMINI_API_KEY va GEMINI_MODEL.")
        return 1

    prompt = (
        sys.argv[1]
        if len(sys.argv) > 1
        else "Hãy giới thiệu vai trò của VieGym trong tối đa 3 câu."
    )

    started = time.perf_counter()

    try:
        with genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(timeout=60_000),
        ) as client:
            response = client.models.generate_content(
                model=model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=(
                        "Bạn là trợ lý VieGym. "
                        "Trả lời bằng tiếng Việt, ngắn gọn và dễ hiểu. "
                        "Chỉ hỗ trợ nội dung luyện tập và dinh dưỡng. "
                        "Không chẩn đoán hoặc kê đơn. "
                        "Với vấn đề bệnh lý hoặc chấn thương, "
                        "khuyến nghị người dùng gặp chuyên gia phù hợp."
                    ),
                ),
            )

        elapsed = time.perf_counter() - started
        answer = (response.text or "").strip()

        if not answer:
            print("DA NHAN PHAN HOI NHUNG KHONG CO NOI DUNG VAN BAN.")
            return 1

        print("KET NOI THANH CONG")
        print(f"Model: {model}")
        print(f"Thoi gian: {elapsed:.2f} giay")
        print("\nPhan hoi:")
        print(answer)

        usage = response.usage_metadata
        if usage:
            print(f"\nTong token: {usage.total_token_count}")

        return 0

    except Exception as exc:
        # Không in toàn bộ lỗi để tránh vô tình lộ cấu hình.
        print("KET NOI THAT BAI")
        print(f"Loai loi: {type(exc).__name__}")
        print(f"Ma loi: {getattr(exc, 'code', 'khong co')}")
        print("Kiem tra key, model, han muc va ket noi mang.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())