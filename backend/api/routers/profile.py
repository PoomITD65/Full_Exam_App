from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text

from core.db import engine
from core.security import get_user_id
from schemas.profile import UpdatePersonReq

router = APIRouter()

def _select_person_sql():
    return text("""
        SELECT
          p.PersonNo, p.IDs, p.PrefixNo, p.FName, p.LName, p.FNameEN, p.LNameEN,
          p.Address, p.Mobile, p.Email, p.Position, p.GroupNo,
          p.Created_at, p.Updated_at, p.Status, p.DeviceID, p.DeviceDetail, p.Photo,
          p.Address_no, p.Address_moo, p.Address_road, p.Address_soi, p.Address_district
        FROM tblPerson p
        WHERE p.PersonNo = (
          SELECT u.MemberNo
          FROM tblUsers u
          WHERE u.UserNo = :uid
          LIMIT 1
        )
        LIMIT 1
    """)

@router.get("", summary="อ่านโปรไฟล์บุคคล (tblPerson) ที่แมพกับบัญชีปัจจุบัน")
def get_person_profile(uid: int = Depends(get_user_id)):
    with engine.connect() as conn:
        row = conn.execute(_select_person_sql(), {"uid": uid}).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Person not found for this account")
    return {"person": row}

@router.put("", summary="อัปเดตโปรไฟล์บุคคล (tblPerson)")
def update_person_profile(payload: UpdatePersonReq, uid: int = Depends(get_user_id)):
    # ดึง PersonNo จาก MemberNo โดยใช้ UserNo
    with engine.connect() as conn:
        pid = conn.execute(text("""
            SELECT u.MemberNo
            FROM tblUsers u
            WHERE u.UserNo = :uid
            LIMIT 1
        """), {"uid": uid}).scalar()

    if not pid:
        raise HTTPException(status_code=404, detail="Mapping to PersonNo not found")

    sets, params = [], {"pid": pid}

    def _add(field_db: str, value):
        if value is not None:
            sets.append(f"{field_db} = :{field_db}")
            params[field_db] = value.strip() if isinstance(value, str) else value

    _add("PrefixNo", payload.prefixNo)
    _add("FName", payload.fName)
    _add("LName", payload.lName)
    _add("FNameEN", payload.fNameEN)
    _add("LNameEN", payload.lNameEN)
    _add("Mobile", payload.mobile)
    _add("Email", payload.email)
    _add("Address", payload.address)
    _add("Address_no", payload.address_no)
    _add("Address_moo", payload.address_moo)
    _add("Address_road", payload.address_road)
    _add("Address_soi", payload.address_soi)
    _add("Address_district", payload.address_district)
    _add("Position", payload.position)
    _add("Photo", payload.photo)
    _add("Status", payload.status)

    if not sets:
        return {"ok": True, "updated": 0}

    sql_upd = text(f"""
        UPDATE tblPerson
        SET {", ".join(sets)}, Updated_at = NOW()
        WHERE PersonNo = :pid
        LIMIT 1
    """)
    with engine.begin() as conn:
        res = conn.execute(sql_upd, params)
        row = conn.execute(_select_person_sql(), {"uid": uid}).mappings().first()

    return {"ok": True, "updated": res.rowcount, "person": row}
