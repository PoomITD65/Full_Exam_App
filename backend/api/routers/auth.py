from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import text

from core.db import engine
from core.security import verify_password, create_access_token, require_and_decode
from schemas.auth import LoginRequest

router = APIRouter()

@router.post("/login", summary="Login with tblUsers (Username/Password)")
def login(payload: LoginRequest):
    sql = text("""
        SELECT
            UserNo, MemberNo, SchoolNo, StdNo, Name, Username, Password,
            LineUserId, LineNotifyToken, DeviceID, DeviceDetail, Token,
            IsUse, UserRole, UserRoleYear, Manager, Created_at, Updated_at
        FROM tblUsers
        WHERE Username = :u
        LIMIT 1
    """)
    with engine.connect() as conn:
        row = conn.execute(sql, {"u": payload.username}).mappings().first()

    if not row or not verify_password(payload.password, row["Password"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")

    if str(row.get("IsUse", "1")).lower() in ("0", "false", "no"):
        raise HTTPException(status_code=403, detail="Account disabled")

    token = create_access_token({
        "sub": str(row["UserNo"]),
        "username": row["Username"],
        "role": row.get("UserRole"),
        "schoolNo": row.get("SchoolNo"),
    })

    user = {
        "userNo": row["UserNo"],
        "memberNo": row.get("MemberNo"),
        "schoolNo": row.get("SchoolNo"),
        "stdNo": row.get("StdNo"),
        "name": row.get("Name"),
        "username": row.get("Username"),
        "isUse": row.get("IsUse"),
        "userRole": row.get("UserRole"),
        "userRoleYear": row.get("UserRoleYear"),
        "manager": row.get("Manager"),
        "createdAt": row.get("Created_at"),
        "updatedAt": row.get("Updated_at"),
    }
    return {"access_token": token, "token_type": "bearer", "user": user}

@router.get("/me", summary="Get current user from JWT")
def me(request: Request, claims: dict = Depends(require_and_decode)):
    user_sql = text("""
        SELECT UserNo, Name, Username, SchoolNo, UserRole, IsUse
        FROM tblUsers
        WHERE UserNo = :id
        LIMIT 1
    """)
    with engine.connect() as conn:
        row = conn.execute(user_sql, {"id": claims.get("sub")}).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    return {"user": row, "claims": claims}
