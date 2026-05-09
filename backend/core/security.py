import re
import hmac
import bcrypt
import jwt
from datetime import datetime, timedelta
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .config import JWT_SECRET, JWT_ALGO, ACCESS_TOKEN_EXPIRE_MINUTES

security = HTTPBearer()

# รองรับ bcrypt และ plaintext
_BCRYPT_RE = re.compile(r"^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$")

def verify_password(plain: str | None, stored: str | None) -> bool:
    if plain is None or stored is None:
        return False
    p = str(plain)
    s = str(stored).strip()
    if not s:
        return False
    if _BCRYPT_RE.match(s):
        try:
            return bcrypt.checkpw(p.encode("utf-8"), s.encode("utf-8"))
        except Exception:
            return False
    return hmac.compare_digest(p, s)

def create_access_token(data: dict, expires_minutes: int = ACCESS_TOKEN_EXPIRE_MINUTES) -> str:
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + timedelta(minutes=expires_minutes)
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGO)

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> int:
    if not credentials or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    claims = decode_token(credentials.credentials)
    try:
        return int(claims.get("sub"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token subject")

def require_and_decode(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    # ใช้ใน /auth/me เพื่อ debug header เวลา client ไม่ส่ง Authorization
    print("=== HEADERS ===", dict(request.headers))
    if not credentials or not credentials.scheme or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    return decode_token(credentials.credentials)
