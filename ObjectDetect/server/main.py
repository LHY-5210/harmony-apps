"""智能物品识别助手 - 云端后端（FastAPI）

功能：
- JWT 鉴权（设备标识 + 密钥换 token，支持刷新）
- 识别记录同步（recordId 幂等）
- 云端查询（时间 / 类别筛选 + 分页）与统计
- 模型版本管理与下载（热更新）

启动：python -m uvicorn main:app --host 0.0.0.0 --port 8000
"""

import base64
import hashlib
import hmac
import json
import os
import sqlite3
import threading
import time
from typing import List, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel

# ---------------------------------------------------------------- 配置
DEVICE_SECRET = "objectdetect-2026"
JWT_SECRET = "objectdetect-jwt-secret"
TOKEN_TTL = 30 * 60          # token 有效期 30 分钟
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cloud.db")
MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
MODEL_VERSION = "v1.1.0"
MODEL_FILE = os.path.join(MODEL_DIR, "yolov8n.ms")

app = FastAPI(title="ObjectDetect Cloud", version="1.0.0")
db_lock = threading.Lock()


# ---------------------------------------------------------------- 数据库
def get_conn():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    os.makedirs(MODEL_DIR, exist_ok=True)
    with db_lock, get_conn() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS records (
                record_id  TEXT PRIMARY KEY,
                device_id  TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                summary    TEXT,
                labels     TEXT,
                boxes      TEXT,
                img_w      INTEGER,
                img_h      INTEGER,
                uploaded_at INTEGER
            )"""
        )


init_db()


# ---------------------------------------------------------------- JWT（HS256，纯标准库实现）
def _b64e(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _b64d(txt: str) -> bytes:
    pad = "=" * (-len(txt) % 4)
    return base64.urlsafe_b64decode(txt + pad)


def make_token(device_id: str) -> dict:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {"sub": device_id, "iat": now, "exp": now + TOKEN_TTL}
    signing_input = f"{_b64e(json.dumps(header).encode())}.{_b64e(json.dumps(payload).encode())}"
    sig = hmac.new(JWT_SECRET.encode(), signing_input.encode(), hashlib.sha256).digest()
    return {"token": f"{signing_input}.{_b64e(sig)}", "expiresIn": TOKEN_TTL}


def verify_token(token: str) -> str:
    try:
        head, body, sig = token.split(".")
        expected = hmac.new(JWT_SECRET.encode(), f"{head}.{body}".encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(expected, _b64d(sig)):
            raise HTTPException(status_code=401, detail="invalid signature")
        payload = json.loads(_b64d(body))
        if payload.get("exp", 0) < int(time.time()):
            raise HTTPException(status_code=401, detail="token expired")
        return payload["sub"]
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="malformed token")


def current_device(authorization: Optional[str] = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    return verify_token(authorization[7:])


# ---------------------------------------------------------------- 数据模型
class AuthRequest(BaseModel):
    deviceId: str
    secret: str


class Box(BaseModel):
    x1: float
    y1: float
    x2: float
    y2: float
    score: float
    classId: int = 0
    label: str = ""


class RecordIn(BaseModel):
    recordId: str
    createdAt: int
    summary: str = ""
    labels: List[str] = []
    boxes: List[Box] = []
    imgW: int = 0
    imgH: int = 0


# ---------------------------------------------------------------- 鉴权接口
@app.post("/api/auth/token")
def issue_token(req: AuthRequest):
    if req.secret != DEVICE_SECRET:
        raise HTTPException(status_code=401, detail="invalid device secret")
    return make_token(req.deviceId)


@app.post("/api/auth/refresh")
def refresh_token(device: str = Depends(current_device)):
    return make_token(device)


# ---------------------------------------------------------------- 记录同步
@app.post("/api/records")
def upload_record(rec: RecordIn, device: str = Depends(current_device)):
    """recordId 幂等：已存在则直接返回 existed，不重复写入。"""
    labels = ",".join(rec.labels)
    boxes = json.dumps([b.dict() for b in rec.boxes], ensure_ascii=False)
    with db_lock, get_conn() as conn:
        row = conn.execute(
            "SELECT record_id FROM records WHERE record_id = ?", (rec.recordId,)
        ).fetchone()
        if row is not None:
            return {"recordId": rec.recordId, "existed": True}
        conn.execute(
            """INSERT INTO records
               (record_id, device_id, created_at, summary, labels, boxes, img_w, img_h, uploaded_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (rec.recordId, device, rec.createdAt, rec.summary, labels, boxes,
             rec.imgW, rec.imgH, int(time.time())),
        )
    return {"recordId": rec.recordId, "existed": False}


@app.get("/api/records")
def list_records(
    from_ts: int = Query(0, alias="from"),
    to_ts: int = Query(0, alias="to"),
    label: str = Query(""),
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    device: str = Depends(current_device),
):
    where, args = ["1=1"], []
    if from_ts > 0:
        where.append("created_at >= ?")
        args.append(from_ts)
    if to_ts > 0:
        where.append("created_at <= ?")
        args.append(to_ts)
    if label:
        where.append("labels LIKE ?")
        args.append(f"%{label}%")
    cond = " AND ".join(where)
    with db_lock, get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) c FROM records WHERE {cond}", args).fetchone()["c"]
        rows = conn.execute(
            f"""SELECT * FROM records WHERE {cond}
                ORDER BY created_at DESC LIMIT ? OFFSET ?""",
            args + [pageSize, (page - 1) * pageSize],
        ).fetchall()
    return {
        "total": total,
        "page": page,
        "pageSize": pageSize,
        "items": [dict(r) for r in rows],
    }


@app.get("/api/stats")
def stats(device: str = Depends(current_device)):
    with db_lock, get_conn() as conn:
        total = conn.execute("SELECT COUNT(*) c FROM records").fetchone()["c"]
        rows = conn.execute("SELECT labels FROM records").fetchall()
    counter = {}
    for r in rows:
        for lab in (r["labels"] or "").split(","):
            lab = lab.strip()
            if lab:
                counter[lab] = counter.get(lab, 0) + 1
    ordered = sorted(counter.items(), key=lambda kv: -kv[1])
    return {"total": total, "categories": [{"label": k, "count": v} for k, v in ordered]}


@app.delete("/api/records/{record_id}")
def delete_record(record_id: str, device: str = Depends(current_device)):
    with db_lock, get_conn() as conn:
        cur = conn.execute("DELETE FROM records WHERE record_id = ?", (record_id,))
    return {"deleted": cur.rowcount}


# ---------------------------------------------------------------- 模型管理
@app.get("/api/model/latest")
def model_latest(device: str = Depends(current_device)):
    if not os.path.exists(MODEL_FILE):
        raise HTTPException(status_code=404, detail="model file not ready")
    size = os.path.getsize(MODEL_FILE)
    sha = hashlib.sha256(open(MODEL_FILE, "rb").read()).hexdigest()
    return {
        "version": MODEL_VERSION,
        "size": size,
        "sha256": sha,
        "url": f"/api/model/download/{MODEL_VERSION}",
    }


@app.get("/api/model/download/{version}")
def model_download(version: str, device: str = Depends(current_device)):
    if version != MODEL_VERSION or not os.path.exists(MODEL_FILE):
        raise HTTPException(status_code=404, detail="model version not found")
    return FileResponse(MODEL_FILE, media_type="application/octet-stream",
                        filename=f"yolov8n-{version}.ms")
