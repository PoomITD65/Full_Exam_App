import pymysql
from sqlalchemy import create_engine
from .config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, DB_CHARSET

def _connect_raw():
    # ใช้ Cursor ปกติ (ไม่ใช่ DictCursor) กัน SQLAlchemy error ตอนอ่านเวอร์ชัน
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        db=DB_NAME,
        charset=DB_CHARSET,
        cursorclass=pymysql.cursors.Cursor,
        connect_timeout=5,
        read_timeout=10,
        write_timeout=10,
    )

engine = create_engine(
    "mysql+pymysql://",
    creator=_connect_raw,
    pool_pre_ping=True,
    pool_recycle=1800,
    future=True,
)
