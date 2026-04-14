import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

DATA_DIR = Path(os.getenv("DATA_DIR", "data"))
DATA_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI()


@app.post("/")
async def store(request: Request):
    body = await request.body()
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return JSONResponse({"error": "invalid JSON"}, status_code=400)

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    digest = hashlib.sha256(body).hexdigest()[:16]
    filename = DATA_DIR / f"{ts}_{digest}.json"

    filename.write_bytes(body)
    return {"file": filename.name}
