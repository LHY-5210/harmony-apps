# -*- coding: utf-8 -*-
"""
校园智能失物招领平台 —— 后端 (FastAPI + SQLite)
架构：端侧 AI 采集结构化 + 后端匹配与流程管理
作者：LostFound backend
"""
import sqlite3, hashlib, hmac, base64, json, time, os, re, math, random
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from contextlib import contextmanager

from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

DB_PATH = os.path.join(os.path.dirname(__file__), 'lostfound.db')
JWT_SECRET = 'lostfound-campus-2026-secret'
TOKEN_TTL = 3600 * 24 * 7  # 7 天

# 匹配引擎权重（可配置）
WEIGHTS = {
    'category': 30,   # 类别一致为硬性条件，通过则得满
    'location': 20,
    'time': 20,
    'ocr': 15,
    'text': 15,
}
MATCH_THRESHOLD = 60   # 超过该分自动生成匹配对
CLAIM_TIMEOUT_HOURS = 48   # 认领超时
APPEAL_TIMEOUT_HOURS = 24  # 申诉超时

app = FastAPI(title='LostFound API')
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['*'], allow_headers=['*'])


# ===================== 数据库 =====================
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA foreign_keys = ON')
    return conn


def init_db():
    db = get_db()
    c = db.cursor()
    c.executescript('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user',
        credit_score INTEGER NOT NULL DEFAULT 100,
        ban_claim_count INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS items (
        item_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,           -- lost / found
        category TEXT,
        color TEXT,
        location TEXT,
        event_time REAL,               -- 失物时间 / 拾获时间
        description TEXT,
        ocr_text TEXT,
        image_url TEXT,
        credential_question TEXT,
        credential_answer TEXT,
        status TEXT NOT NULL DEFAULT '待匹配',
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lost_item_id TEXT NOT NULL,
        found_item_id TEXT NOT NULL,
        score REAL NOT NULL,
        factors TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '待确认',
        winner_claim_id INTEGER,
        created_at REAL NOT NULL,
        expires_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS claims (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id INTEGER NOT NULL,
        claimant_id INTEGER NOT NULL,
        answer TEXT,
        answer_score REAL,
        status TEXT NOT NULL DEFAULT '排队',   -- 排队/核验中/通过/拒绝
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS appeals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id INTEGER NOT NULL,
        appellant_id INTEGER NOT NULL,
        evidence_level INTEGER NOT NULL,      -- L1=1 L2=2 L3=3
        evidence_text TEXT,
        status TEXT NOT NULL DEFAULT '待裁定',
        decided_at REAL,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS timeline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id INTEGER,
        item_id TEXT,
        event TEXT NOT NULL,
        actor_id INTEGER,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS credit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sync_queue (
        item_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL
    );
    ''')
    db.commit()
    # 内置管理员 + 测试用户
    now = time.time()
    c.execute('INSERT OR IGNORE INTO users (username,password_hash,role,credit_score,created_at) VALUES (?,?,?,?,?)',
              ('admin', hash_pwd('admin123'), 'admin', 100, now))
    c.execute('INSERT OR IGNORE INTO users (username,password_hash,role,credit_score,created_at) VALUES (?,?,?,?,?)',
              ('demo', hash_pwd('123456'), 'user', 100, now))
    db.commit()
    db.close()


# ===================== 工具 =====================
def hash_pwd(pwd: str) -> str:
    return hashlib.sha256((pwd + '::salt').encode()).hexdigest()


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def make_token(user_id: int, username: str, role: str) -> str:
    header = b64url(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode())
    payload = b64url(json.dumps({
        'uid': user_id, 'sub': username, 'role': role,
        'exp': int(time.time()) + TOKEN_TTL
    }).encode())
    sig = b64url(hmac.new(JWT_SECRET.encode(), f'{header}.{payload}'.encode(), hashlib.sha256).digest())
    return f'{header}.{payload}.{sig}'


def decode_token(token: str) -> Optional[dict]:
    try:
        h, p, s = token.split('.')
        sig = b64url(hmac.new(JWT_SECRET.encode(), f'{h}.{p}'.encode(), hashlib.sha256).digest())
        if sig != s:
            return None
        payload = json.loads(base64.urlsafe_b64decode(p + '===').decode())
        if payload.get('exp', 0) < time.time():
            return None
        return payload
    except Exception:
        return None


def current_user(req: Request) -> dict:
    auth = req.headers.get('Authorization', '')
    if not auth.startswith('Bearer '):
        raise HTTPException(401, '未登录')
    payload = decode_token(auth[7:])
    if not payload:
        raise HTTPException(401, 'token 无效或已过期')
    return payload


def require_admin(user: dict):
    if user.get('role') != 'admin':
        raise HTTPException(403, '需要管理员权限')


def add_timeline(db, match_id, item_id, event, actor_id):
    db.execute('INSERT INTO timeline (match_id,item_id,event,actor_id,created_at) VALUES (?,?,?,?,?)',
               (match_id, item_id, event, actor_id, time.time()))


def adjust_credit(db, user_id, delta, reason):
    db.execute('UPDATE users SET credit_score = credit_score + ? WHERE id = ?', (delta, user_id))
    db.execute('INSERT INTO credit_logs (user_id,delta,reason,created_at) VALUES (?,?,?,?)',
               (user_id, delta, reason, time.time()))


# ===================== AI 适配层（演示实现，可替换为真实服务）=====================
CATEGORY_POOL = ['校园卡', '钥匙', '书本', '水杯', '钱包', '雨伞', '耳机', '手机', '证件', '背包']

def ai_classify(image_b64: str) -> dict:
    # 演示：按图片内容哈希稳定返回一个类别建议
    h = int(hashlib.md5((image_b64[:200] if image_b64 else 'x').encode()).hexdigest(), 16)
    cat = CATEGORY_POOL[h % len(CATEGORY_POOL)]
    return {'category': cat, 'confidence': 0.78 + (h % 20) / 100}


def ai_ocr(image_b64: str) -> dict:
    # 演示：返回典型校园卡文字线索
    h = int(hashlib.md5((image_b64[:100] if image_b64 else 'x').encode()).hexdigest(), 16) % 3
    samples = [
        '广东工业大学 校园卡 姓名:张三 学号:2024010101 学院:计算机学院',
        '《数据结构》(C语言版) 严蔚敏 清华大学出版社 ISBN 9787302147510',
        '学生证 姓名:李四 学号:2023061234 专业:软件工程'
    ]
    return {'text': samples[h]}


def ai_asr(audio_b64: str) -> dict:
    # 演示：返回一段口述描述文本
    samples = [
        '一个黑色的钱包，里面有学生证和银行卡，今天下午三点左右在图书馆二楼丢的',
        '一串钥匙，上面挂着一个蓝色的小熊挂件，昨天晚上在教学楼A栋捡到的',
        '一本红色封面的高数教材，书里夹着几张写了笔记的纸，在食堂捡到的'
    ]
    h = int(hashlib.md5((audio_b64[:100] if audio_b64 else str(time.time())).encode()).hexdigest(), 16) % 3
    return {'text': samples[h]}


def ai_ner(text: str) -> dict:
    # 演示：用关键词规则抽取结构化字段
    color_map = {'黑色': '黑色', '白色': '白色', '红色': '红色', '蓝色': '蓝色', '绿色': '绿色', '黄色': '黄色', '灰色': '灰色'}
    cat_map = {
        '校园卡': '校园卡', '学生证': '证件', '身份证': '证件', '钥匙': '钥匙',
        '书本': '书本', '教材': '书本', '钱包': '钱包', '水杯': '水杯', '雨伞': '雨伞',
        '耳机': '耳机', '手机': '手机', '背包': '背包', '卡': '校园卡'
    }
    loc_words = ['图书馆', '教学楼', '食堂', '宿舍', '操场', '超市', '体育馆', '实验楼']
    time_words = {
        '今天下午': '今天下午', '今天上午': '今天上午', '今天晚上': '今天晚上',
        '昨天': '昨天', '昨天晚上': '昨天晚上', '刚刚': '刚刚', '早上': '早上', '中午': '中午'
    }
    result = {'category': '', 'color': '', 'location': '', 'time': ''}
    for k, v in cat_map.items():
        if k in text and not result['category']:
            result['category'] = v
    for k, v in color_map.items():
        if k in text:
            result['color'] = v
            break
    for w in loc_words:
        if w in text:
            result['location'] = w
            break
    for k, v in time_words.items():
        if k in text:
            result['time'] = v
            break
    return result


# ===================== 匹配引擎 =====================
def jaccard(a: str, b: str) -> float:
    sa = set(re.findall(r'[\u4e00-\u9fa5]+|[\w]+', a)) if a else set()
    sb = set(re.findall(r'[\u4e00-\u9fa5]+|[\w]+', b)) if b else set()
    if not sa or not sb:
        return 0.0
    inter = sa & sb
    union = sa | sb
    return len(inter) / len(union) if union else 0.0


def location_score(a: str, b: str) -> float:
    if not a or not b:
        return 0.3
    if a == b:
        return 1.0
    if a in b or b in a:
        return 0.7
    # 同区关键词
    kw = ['图书馆', '教学楼', '食堂', '宿舍', '操场']
    for k in kw:
        if k in a and k in b:
            return 0.6
    return 0.1


def time_score(lost_time, found_time) -> float:
    if not lost_time or not found_time:
        return 0.3
    try:
        lt = float(lost_time)
        ft = float(found_time)
    except (TypeError, ValueError):
        return 0.3
    diff_h = (ft - lt) / 3600
    if diff_h < 0:
        return 0.0  # 失物时间应早于拾获时间
    if diff_h <= 24:
        return 1.0
    if diff_h <= 72:
        return 0.7
    if diff_h <= 168:
        return 0.4
    return 0.1


def ocr_score(a: str, b: str) -> float:
    if not a or not b:
        return 0.2
    if a == b:
        return 1.0
    # 学号/数字线索重合
    nums_a = set(re.findall(r'\d{6,}', a))
    nums_b = set(re.findall(r'\d{6,}', b))
    if nums_a and nums_b and nums_a & nums_b:
        return 1.0
    # 关键词重合（姓名等）
    ka = set(re.findall(r'[\u4e00-\u9fa5]{2,4}', a))
    kb = set(re.findall(r'[\u4e00-\u9fa5]{2,4}', b))
    if ka & kb:
        return 0.8
    return 0.1


def match_score(lost, found, weights=None) -> Dict[str, Any]:
    w = weights or WEIGHTS
    # 类别一致为硬性条件
    cat_ok = lost.get('category') and found.get('category') and lost['category'] == found['category']
    factors = {
        'category': 1.0 if cat_ok else 0.0,
        'location': location_score(lost.get('location', ''), found.get('location', '')),
        'time': time_score(lost.get('event_time'), found.get('event_time')),
        'ocr': ocr_score(lost.get('ocr_text', ''), found.get('ocr_text', '')),
        'text': jaccard(lost.get('description', ''), found.get('description', '')),
    }
    score = sum(factors[k] * w[k] for k in w)
    return {'score': round(score, 2), 'factors': factors, 'category_match': cat_ok}


def run_matching(db, item):
    """为新发布物品跑匹配，生成候选/自动匹配对"""
    if item['type'] == 'lost':
        rows = db.execute('SELECT * FROM items WHERE type=? AND status=? AND item_id<>?',
                          ('found', '待匹配', item['item_id'])).fetchall()
    else:
        rows = db.execute('SELECT * FROM items WHERE type=? AND status=? AND item_id<>?',
                          ('lost', '待匹配', item['item_id'])).fetchall()
    candidates = []
    for r in rows:
        other = dict(r)
        res = match_score(item, other)
        if res['category_match']:  # 硬性条件
            candidates.append({'item': other, **res})
    candidates.sort(key=lambda x: x['score'], reverse=True)
    # 自动生成匹配对（超过阈值且物品仍待匹配）
    for c in candidates:
        if c['score'] >= MATCH_THRESHOLD:
            lost_id = item['item_id'] if item['type'] == 'lost' else c['item']['item_id']
            found_id = c['item']['item_id'] if item['type'] == 'lost' else item['item_id']
            exists = db.execute('SELECT id FROM matches WHERE lost_item_id=? AND found_item_id=?',
                                (lost_id, found_id)).fetchone()
            if not exists:
                now = time.time()
                cur = db.execute('INSERT INTO matches (lost_item_id,found_item_id,score,factors,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)',
                                 (lost_id, found_id, c['score'], json.dumps(c['factors']), '待确认', now, now + CLAIM_TIMEOUT_HOURS * 3600))
                db.execute("UPDATE items SET status='已匹配待确认' WHERE item_id IN (?,?)", (lost_id, found_id))
                add_timeline(db, cur.lastrowid, lost_id, '自动匹配成功', 0)
                add_timeline(db, cur.lastrowid, found_id, '自动匹配成功', 0)
            break  # 只取最高分自动生成一对，其余作为候选
    db.commit()
    return candidates


# ===================== Pydantic 模型 =====================
class LoginReq(BaseModel):
    username: str
    password: str


class RegReq(BaseModel):
    username: str
    password: str


class ImageReq(BaseModel):
    image: str = ''


class AudioReq(BaseModel):
    audio: str = ''


class TextReq(BaseModel):
    text: str = ''


class ItemReq(BaseModel):
    itemId: str
    type: str                      # lost / found
    category: str = ''
    color: str = ''
    location: str = ''
    eventTime: float = 0
    description: str = ''
    ocrText: str = ''
    imageUrl: str = ''
    credentialQuestion: str = ''
    credentialAnswer: str = ''


class ClaimReq(BaseModel):
    answer: str = ''


class AppealReq(BaseModel):
    evidenceLevel: int        # 1/2/3
    evidenceText: str = ''


class DecideReq(BaseModel):
    result: str               # 成立 / 不成立


# ===================== 路由 =====================
@app.get('/api/health')
def health():
    return {'ok': True, 'ts': time.time()}


# ---------- 鉴权 ----------
@app.post('/api/auth/register')
def register(req: RegReq):
    db = get_db()
    try:
        db.execute('INSERT INTO users (username,password_hash,role,credit_score,created_at) VALUES (?,?,?,?,?)',
                   (req.username, hash_pwd(req.password), 'user', 100, time.time()))
        db.commit()
        return {'ok': True}
    except sqlite3.IntegrityError:
        raise HTTPException(400, '用户名已存在')
    finally:
        db.close()


@app.post('/api/auth/token')
def login(req: LoginReq):
    db = get_db()
    u = db.execute('SELECT * FROM users WHERE username=?', (req.username,)).fetchone()
    db.close()
    if not u or u['password_hash'] != hash_pwd(req.password):
        raise HTTPException(401, '用户名或密码错误')
    token = make_token(u['id'], u['username'], u['role'])
    return {'token': token, 'expiresIn': TOKEN_TTL,
            'user': {'id': u['id'], 'username': u['username'], 'role': u['role'],
                     'creditScore': u['credit_score'], 'banClaimCount': u['ban_claim_count']}}


@app.get('/api/auth/me')
def me(user: dict = Depends(current_user)):
    db = get_db()
    u = db.execute('SELECT * FROM users WHERE id=?', (user['uid'],)).fetchone()
    db.close()
    if not u:
        raise HTTPException(404, '用户不存在')
    return {'id': u['id'], 'username': u['username'], 'role': u['role'],
            'creditScore': u['credit_score'], 'banClaimCount': u['ban_claim_count']}


# ---------- AI ----------
@app.post('/api/ai/classify')
def classify(req: ImageReq, user: dict = Depends(current_user)):
    return ai_classify(req.image)


@app.post('/api/ai/ocr')
def ocr(req: ImageReq, user: dict = Depends(current_user)):
    return ai_ocr(req.image)


@app.post('/api/ai/asr')
def asr(req: AudioReq, user: dict = Depends(current_user)):
    return ai_asr(req.audio)


@app.post('/api/ai/ner')
def ner(req: TextReq, user: dict = Depends(current_user)):
    return ai_ner(req.text)


# ---------- 物品 ----------
@app.post('/api/items')
def create_item(req: ItemReq, user: dict = Depends(current_user)):
    db = get_db()
    # 信用分低于阈值禁止发布
    u = db.execute('SELECT credit_score FROM users WHERE id=?', (user['uid'],)).fetchone()
    if u['credit_score'] < 30:
        db.close()
        raise HTTPException(403, '信用分过低，禁止发布')
    # 幂等：itemId 已存在则直接返回
    existing = db.execute('SELECT * FROM items WHERE item_id=?', (req.itemId,)).fetchone()
    if existing:
        db.close()
        return {'itemId': req.itemId, 'idempotent': True}
    now = time.time()
    db.execute('''INSERT INTO items (item_id,user_id,type,category,color,location,event_time,description,
                  ocr_text,image_url,credential_question,credential_answer,status,created_at,updated_at)
                  VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
               (req.itemId, user['uid'], req.type, req.category, req.color, req.location, req.eventTime,
                req.description, req.ocrText, req.imageUrl, req.credentialQuestion, req.credentialAnswer,
                '待匹配', now, now))
    add_timeline(db, None, req.itemId, '发布' + ('失物登记' if req.type == 'lost' else '招领启事'), user['uid'])
    item = db.execute('SELECT * FROM items WHERE item_id=?', (req.itemId,)).fetchone()
    candidates = run_matching(db, dict(item))
    db.close()
    return {'itemId': req.itemId, 'candidates': candidates[:10]}


@app.get('/api/items')
def list_items(type: str = '', category: str = '', page: int = 1, pageSize: int = 20):
    db = get_db()
    sql = 'SELECT * FROM items WHERE 1=1'
    args = []
    if type:
        sql += ' AND type=?'; args.append(type)
    if category:
        sql += ' AND category=?'; args.append(category)
    sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?'
    args.extend([pageSize, (page - 1) * pageSize])
    rows = db.execute(sql, args).fetchall()
    db.close()
    return {'items': [dict(r) for r in rows], 'page': page}


@app.get('/api/items/mine')
def my_items(user: dict = Depends(current_user)):
    db = get_db()
    rows = db.execute('SELECT * FROM items WHERE user_id=? ORDER BY created_at DESC', (user['uid'],)).fetchall()
    db.close()
    return {'items': [dict(r) for r in rows]}


@app.get('/api/items/{item_id}')
def get_item(item_id: str):
    db = get_db()
    r = db.execute('SELECT * FROM items WHERE item_id=?', (item_id,)).fetchone()
    db.close()
    if not r:
        raise HTTPException(404, '物品不存在')
    return dict(r)


@app.get('/api/items/{item_id}/candidates')
def candidates(item_id: str):
    db = get_db()
    item = db.execute('SELECT * FROM items WHERE item_id=?', (item_id,)).fetchone()
    if not item:
        db.close(); raise HTTPException(404, '物品不存在')
    res = run_matching(db, dict(item))
    db.close()
    return {'candidates': [{'itemId': c['item']['item_id'], 'score': c['score'], 'factors': c['factors']} for c in res[:10]]}


# ---------- 匹配与认领状态机 ----------
VALID_TRANSITIONS = {
    '待匹配': ['已匹配待确认'],
    '待确认': ['认领申请中', '已关闭'],
    '认领申请中': ['凭证核验中', '已关闭'],
    '凭证核验中': ['竞领中', '已完成', '已关闭'],
    '竞领中': ['已完成', '已关闭'],
    '申诉中': ['已完成', '已关闭'],
    '已完成': ['申诉中'],
    '已关闭': [],
}


def transition(db, match_id, new_status, actor_id, event):
    m = db.execute('SELECT * FROM matches WHERE id=?', (match_id,)).fetchone()
    if not m:
        raise HTTPException(404, '匹配不存在')
    cur = m['status']
    if new_status not in VALID_TRANSITIONS.get(cur, []):
        raise HTTPException(400, f'非法状态流转: {cur} -> {new_status}')
    db.execute('UPDATE matches SET status=? WHERE id=?', (new_status, match_id))
    add_timeline(db, match_id, None, event, actor_id)
    # 同步物品状态
    if new_status in ('已完成', '已关闭'):
        new_item_status = '已匹配' if new_status == '已完成' else '待匹配'
        db.execute('UPDATE items SET status=? WHERE item_id IN (?,?)',
                   (new_item_status, m['lost_item_id'], m['found_item_id']))
    return m


@app.post('/api/matches/{match_id}/claim')
def claim(match_id: int, user: dict = Depends(current_user)):
    db = get_db()
    m = db.execute('SELECT * FROM matches WHERE id=?', (match_id,)).fetchone()
    if not m:
        db.close(); raise HTTPException(404, '匹配不存在')
    # 不能认领自己发布的
    lost = db.execute('SELECT user_id FROM items WHERE item_id=?', (m['lost_item_id'],)).fetchone()
    found = db.execute('SELECT user_id FROM items WHERE item_id=?', (m['found_item_id'],)).fetchone()
    if user['uid'] in (lost['user_id'], found['user_id']):
        db.close(); raise HTTPException(400, '不能认领自己发布的物品')
    # 检查是否已在队列
    ex = db.execute('SELECT id FROM claims WHERE match_id=? AND claimant_id=? AND status IN (?,?,?)',
                    (match_id, user['uid'], '排队', '核验中', '通过')).fetchone()
    if ex:
        db.close(); raise HTTPException(400, '已提交认领申请')
    now = time.time()
    cur = db.execute('INSERT INTO claims (match_id,claimant_id,status,created_at) VALUES (?,?,?,?)',
                     (match_id, user['uid'], '排队', now))
    # 状态流转：待确认 -> 认领申请中
    transition(db, match_id, '认领申请中', user['uid'], '用户提交认领申请')
    # 串行核验：若当前无核验中，则把该申请设为核验中
    active = db.execute('SELECT id FROM claims WHERE match_id=? AND status=?', (match_id, '核验中')).fetchone()
    if not active:
        db.execute('UPDATE claims SET status=? WHERE id=?', ('核验中', cur.lastrowid))
        transition(db, match_id, '凭证核验中', user['uid'], '进入凭证核验')
    db.commit()
    db.close()
    return {'claimId': cur.lastrowid, 'status': '核验中' if not active else '排队'}


@app.post('/api/claims/{claim_id}/verify')
def verify_claim(claim_id: int, req: ClaimReq, user: dict = Depends(current_user)):
    db = get_db()
    cl = db.execute('SELECT * FROM claims WHERE id=?', (claim_id,)).fetchone()
    if not cl:
        db.close(); raise HTTPException(404, '申请不存在')
    if cl['claimant_id'] != user['uid']:
        db.close(); raise HTTPException(403, '无权操作')
    if cl['status'] != '核验中':
        db.close(); raise HTTPException(400, '当前不处于核验状态')
    # 取招领方的凭证答案
    m = db.execute('SELECT * FROM matches WHERE id=?', (cl['match_id'],)).fetchone()
    found = db.execute('SELECT credential_answer FROM items WHERE item_id=?', (m['found_item_id'],)).fetchone()
    correct = found['credential_answer'] or ''
    # 答案评分：完全一致1分，部分包含0.5，否则0
    ans = req.answer.strip()
    if correct and ans == correct:
        score = 1.0
    elif correct and (ans in correct or correct in ans):
        score = 0.5
    else:
        score = 0.0
    db.execute('UPDATE claims SET answer=?, answer_score=?, status=? WHERE id=?',
               (ans, score, '通过' if score >= 0.5 else '拒绝', claim_id))
    add_timeline(db, cl['match_id'], None, f'凭证作答: {ans} (得分{score})', user['uid'])
    if score < 0.5:
        # 核验失败，释放队列，下一位进入核验
        promote_next(db, cl['match_id'])
    db.commit()
    db.close()
    return {'score': score, 'passed': score >= 0.5}


def promote_next(db, match_id):
    """将排队中的下一个申请提升为核验中；若无则匹配关闭"""
    nxt = db.execute('SELECT id FROM claims WHERE match_id=? AND status=? ORDER BY created_at ASC LIMIT 1',
                     (match_id, '排队')).fetchone()
    if nxt:
        db.execute('UPDATE claims SET status=? WHERE id=?', ('核验中', nxt['id']))
        add_timeline(db, match_id, None, '下一位竞领者进入凭证核验', 0)
    else:
        transition(db, match_id, '已关闭', 0, '无有效认领申请，自动关闭')


@app.post('/api/matches/{match_id}/confirm')
def confirm(match_id: int, user: dict = Depends(current_user)):
    db = get_db()
    m = db.execute('SELECT * FROM matches WHERE id=?', (match_id,)).fetchone()
    if not m:
        db.close(); raise HTTPException(404, '匹配不存在')
    # 只有通过核验的认领者才能确认完成
    passed = db.execute('SELECT * FROM claims WHERE match_id=? AND status=?', (match_id, '通过')).fetchall()
    if not passed:
        db.close(); raise HTTPException(400, '须先通过凭证核验')
    # 多位通过时按答案得分+信用分择优
    best = max(passed, key=lambda c: (c['answer_score'], db.execute('SELECT credit_score FROM users WHERE id=?', (c['claimant_id'],)).fetchone()['credit_score']))
    # 拒绝其余
    for c in passed:
        if c['id'] != best['id']:
            db.execute('UPDATE claims SET status=? WHERE id=?', ('拒绝', c['id']))
    db.execute('UPDATE matches SET winner_claim_id=? WHERE id=?', (best['id'], match_id))
    transition(db, match_id, '已完成', user['uid'], '认领完成')
    # 信用分加分
    adjust_credit(db, best['claimant_id'], 5, '完成认领')
    # 拒绝者通知（此处仅记日志）
    for c in passed:
        if c['id'] != best['id']:
            adjust_credit(db, c['claimant_id'], 0, '竞领落选')
    db.commit()
    db.close()
    return {'winner': best['claimant_id']}


@app.post('/api/matches/{match_id}/close')
def close_match(match_id: int, user: dict = Depends(current_user)):
    db = get_db()
    try:
        transition(db, match_id, '已关闭', user['uid'], '用户关闭匹配')
        db.commit()
    finally:
        db.close()
    return {'ok': True}


@app.get('/api/matches/{match_id}/timeline')
def timeline(match_id: int):
    db = get_db()
    rows = db.execute('SELECT * FROM timeline WHERE match_id=? ORDER BY created_at ASC', (match_id,)).fetchall()
    db.close()
    return {'events': [dict(r) for r in rows]}


@app.get('/api/matches')
def list_matches(item_id: str = ''):
    db = get_db()
    if item_id:
        rows = db.execute('SELECT * FROM matches WHERE lost_item_id=? OR found_item_id=? ORDER BY created_at DESC',
                          (item_id, item_id)).fetchall()
    else:
        rows = db.execute('SELECT * FROM matches ORDER BY created_at DESC LIMIT 50').fetchall()
    db.close()
    return {'matches': [dict(r) for r in rows]}


# ---------- 冒领申诉 ----------
@app.post('/api/matches/{match_id}/appeal')
def appeal(match_id: int, req: AppealReq, user: dict = Depends(current_user)):
    db = get_db()
    m = db.execute('SELECT * FROM matches WHERE id=?', (match_id,)).fetchone()
    if not m or m['status'] != '已完成':
        db.close(); raise HTTPException(400, '仅已完成的匹配可申诉')
    winner = db.execute('SELECT answer_score FROM claims WHERE id=?', (m['winner_claim_id'],)).fetchone()
    # 原认领者核验证据等级：答案得分映射 L1=1
    orig_level = 1
    if req.evidenceLevel <= orig_level:
        db.close(); raise HTTPException(400, '申诉证据等级须高于原核验等级')
    cur = db.execute('INSERT INTO appeals (match_id,appellant_id,evidence_level,evidence_text,status,created_at) VALUES (?,?,?,?,?,?)',
                     (match_id, user['uid'], req.evidenceLevel, req.evidenceText, '待裁定', time.time()))
    transition(db, match_id, '申诉中', user['uid'], '发起冒领申诉')
    db.commit()
    db.close()
    return {'appealId': cur.lastrowid}


@app.get('/api/admin/appeals')
def admin_appeals(user: dict = Depends(current_user)):
    require_admin(user)
    db = get_db()
    rows = db.execute('SELECT * FROM appeals ORDER BY created_at DESC').fetchall()
    db.close()
    return {'appeals': [dict(r) for r in rows]}


@app.post('/api/appeals/{appeal_id}/decide')
def decide_appeal(appeal_id: int, req: DecideReq, user: dict = Depends(current_user)):
    # 管理员或发布者可裁定
    db = get_db()
    a = db.execute('SELECT * FROM appeals WHERE id=?', (appeal_id,)).fetchone()
    if not a:
        db.close(); raise HTTPException(404, '申诉不存在')
    if a['status'] != '待裁定':
        db.close(); raise HTTPException(400, '申诉已裁定')
    m = db.execute('SELECT * FROM matches WHERE id=?', (a['match_id'],)).fetchone()
    found = db.execute('SELECT user_id FROM items WHERE item_id=?', (m['found_item_id'],)).fetchone()
    if user.get('role') != 'admin' and user['uid'] != found['user_id']:
        db.close(); raise HTTPException(403, '仅管理员或发布者可裁定')
    if req.result == '成立':
        # 原认领关闭，物品回待匹配，优先推送申诉人
        db.execute('UPDATE matches SET status=? WHERE id=?', ('已关闭', a['match_id']))
        db.execute('UPDATE items SET status=? WHERE item_id IN (?,?)', ('待匹配', m['lost_item_id'], m['found_item_id']))
        adjust_credit(db, db.execute('SELECT claimant_id FROM claims WHERE id=?', (m['winner_claim_id'],)).fetchone()['claimant_id'], -20, '冒领成立')
        adjust_credit(db, a['appellant_id'], 0, '冒领申诉成立')
        add_timeline(db, a['match_id'], None, '申诉裁定: 冒领成立', user['uid'])
    else:
        adjust_credit(db, a['appellant_id'], -10, '恶意申诉')
        add_timeline(db, a['match_id'], None, '申诉裁定: 冒领不成立', user['uid'])
    db.execute('UPDATE appeals SET status=?, decided_at=? WHERE id=?',
               ('冒领成立' if req.result == '成立' else '不成立', time.time(), appeal_id))
    db.commit()
    db.close()
    return {'ok': True}


# ---------- 信用分 ----------
@app.get('/api/me/credit')
def my_credit(user: dict = Depends(current_user)):
    db = get_db()
    u = db.execute('SELECT credit_score,ban_claim_count FROM users WHERE id=?', (user['uid'],)).fetchone()
    logs = db.execute('SELECT * FROM credit_logs WHERE user_id=? ORDER BY created_at DESC LIMIT 20', (user['uid'],)).fetchall()
    db.close()
    return {'creditScore': u['credit_score'], 'banClaimCount': u['ban_claim_count'], 'logs': [dict(l) for l in logs]}


# ---------- 管理员 ----------
@app.get('/api/admin/stats')
def admin_stats(user: dict = Depends(current_user)):
    require_admin(user)
    db = get_db()
    stats = {
        'items': db.execute('SELECT COUNT(*) c FROM items').fetchone()['c'],
        'matches': db.execute('SELECT COUNT(*) c FROM matches').fetchone()['c'],
        'completed': db.execute("SELECT COUNT(*) c FROM matches WHERE status='已完成'").fetchone()['c'],
        'appeals_pending': db.execute("SELECT COUNT(*) c FROM appeals WHERE status='待裁定'").fetchone()['c'],
        'users': db.execute('SELECT COUNT(*) c FROM users').fetchone()['c'],
    }
    db.close()
    return stats


@app.get('/api/admin/banned')
def admin_banned(user: dict = Depends(current_user)):
    require_admin(user)
    db = get_db()
    rows = db.execute('SELECT id,username,credit_score,ban_claim_count FROM users WHERE credit_score < 30 OR ban_claim_count >= 3 ORDER BY credit_score ASC').fetchall()
    db.close()
    return {'users': [dict(r) for r in rows]}


# ---------- 数据同步 ----------
@app.get('/api/sync/items')
def sync_items(since: float = 0, user: dict = Depends(current_user)):
    db = get_db()
    rows = db.execute('SELECT * FROM items WHERE updated_at > ? ORDER BY updated_at ASC', (since,)).fetchall()
    db.close()
    return {'items': [dict(r) for r in rows], 'timestamp': time.time()}


# ---------- 演示：权重调节 ----------
@app.post('/api/demo/match-score')
def demo_score(req: dict):
    """演示权重调节对匹配分的影响"""
    lost = req.get('lost', {})
    found = req.get('found', {})
    weights = req.get('weights') or WEIGHTS
    return match_score(lost, found, weights)


@app.on_event('startup')
def on_startup():
    init_db()


if __name__ == '__main__':
    import uvicorn
    init_db()
    uvicorn.run(app, host='0.0.0.0', port=8000)
