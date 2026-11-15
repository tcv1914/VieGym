# Ảnh chạy ai-service cho staging. Biến môi trường do compose truyền vào; không copy .env.
FROM python:3.13-slim
RUN useradd --system --no-create-home viegym
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py providers.py ./
USER viegym
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
