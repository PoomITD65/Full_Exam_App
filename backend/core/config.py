import os
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parents[1] / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)

def env(name, default=None, *, required=False, cast=str):
    v = os.getenv(name, default)
    if isinstance(v, str):
        v = v.strip()
    if required and (v is None or v == ""):
        raise RuntimeError(f"Missing env: {name}")
    return cast(v) if (v is not None and cast is not str) else v

DB_HOST     = env("DB_HOST", "localhost")
DB_PORT     = env("DB_PORT", "3306", cast=int)
DB_USER     = env("DB_USER", required=True)
DB_PASSWORD = env("DB_PASSWORD", required=True)
DB_NAME     = env("DB_NAME", required=True)
DB_CHARSET  = env("DB_CHARSET", "utf8mb4")

JWT_SECRET  = env("JWT_SECRET", "change-me-please")
JWT_ALGO    = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 ชั่วโมง
