from fastapi import FastAPI

app = FastAPI(title="VieGym AI Service")


@app.get("/health")
def health():
    return {"status": "UP", "service": "viegym-ai"}
