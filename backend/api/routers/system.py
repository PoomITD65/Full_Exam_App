import sys, traceback
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse
from sqlalchemy import text

from core.db import engine
from core.config import DB_NAME

router = APIRouter(tags=["system"])

@router.get("/db/health", summary="Check DB connection and show status")
def db_health(db: str | None = Query(None, description="schema ที่ต้องการตรวจ; ไม่ระบุ = DB_NAME ใน .env")):
    try:
        target_db = db or DB_NAME
        with engine.connect() as conn:
            conn.exec_driver_sql("SELECT 1")
            version      = conn.exec_driver_sql("SELECT VERSION()").scalar()
            active_db    = conn.exec_driver_sql("SELECT DATABASE()").scalar()
            user_func    = conn.exec_driver_sql("SELECT USER()").scalar()
            current_user = conn.exec_driver_sql("SELECT CURRENT_USER()").scalar()

            schema_exists = int(conn.execute(
                text("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=:db"),
                {"db": target_db}
            ).scalar() or 0) > 0

            table_count = 0
            if schema_exists:
                table_count = int(conn.execute(
                    text("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=:db"),
                    {"db": target_db}
                ).scalar() or 0)

        return {
            "ok": True,
            "server_version": version,
            "database_active": active_db,
            "database_checked": target_db,
            "schema_exists": schema_exists,
            "table_count": table_count,
            "server_sees_user": user_func,
            "current_user": current_user,
        }
    except Exception as e:
        print("ERROR /db/health:", repr(e), file=sys.stderr)
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})

@router.get("/tables", summary="List all tables (default = DB_NAME from .env)")
def list_tables(db: str | None = Query(None, description="schema ที่ต้องการ; ไม่ระบุ = DB_NAME")):
    try:
        target_db = db or DB_NAME
        with engine.connect() as conn:
            exists = int(conn.execute(
                text("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=:db"),
                {"db": target_db}
            ).scalar() or 0)
            if exists == 0:
                raise HTTPException(status_code=404, detail=f"Schema '{target_db}' not found or no permission")

            tables = conn.execute(
                text("""
                    SELECT TABLE_NAME
                    FROM information_schema.TABLES
                    WHERE TABLE_SCHEMA = :db
                    ORDER BY TABLE_NAME
                """),
                {"db": target_db},
            ).scalars().all()

        return {"database": target_db, "count": len(tables), "tables": tables}
    except HTTPException:
        raise
    except Exception as e:
        print("ERROR /tables:", repr(e), file=sys.stderr)
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})
