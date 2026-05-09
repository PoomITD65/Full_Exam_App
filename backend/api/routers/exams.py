# api/routers/exams.py
from fastapi import APIRouter, Depends, HTTPException, Query, Body
from sqlalchemy import text, bindparam
from sqlalchemy.types import Integer   # ✅ ถูกที่
from core.db import engine
from core.security import get_user_id
from schemas.exams import CreateExamReq

router = APIRouter()

def _parse_class_list(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [c.strip() for c in raw.replace(";", ",").split(",") if c.strip()]


def _table_columns(conn, table_name: str) -> set[str]:
    rows = conn.execute(text(f"SHOW COLUMNS FROM `{table_name}`")).mappings().all()
    return {str(r.get("Field") or "") for r in rows}


def _table_exists(conn, table_name: str) -> bool:
    return int(conn.execute(
        text("""
            SELECT COUNT(*)
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = :table_name
        """),
        {"table_name": table_name},
    ).scalar() or 0) > 0


@router.get("/daily_summary", summary="สรุปจำนวนการอัปเดตผลรายวัน (tblAcdQuizResult)")
def daily_summary(
    start: str = Query(..., description="YYYY-MM-DD"),
    end: str = Query(..., description="YYYY-MM-DD (รวมถึงวันนี้)"),
    quizId: int | None = Query(None),
    user_id: int = Depends(get_user_id),
):
    """
    คืนจำนวนรายการที่อัปเดตใน `tblAcdQuizResult` แยกตามวัน
    - กรองช่วงวันที่ด้วย Updated_at
    - ถ้าระบุ `quizId` จะกรองเฉพาะควิซนั้น
    - ผูกกับผู้ใช้: จะพยายามกรองตาม `PersonNo` ถ้ามีคอลัมน์ในตาราง
    """
    # ตรวจว่ามีคอลัมน์ PersonNo หรือไม่ เพื่อกรองตามผู้ใช้
    with engine.connect() as conn:
        if not _table_exists(conn, "tblAcdQuizResult"):
            return {"items": []}
        try:
            cols = _table_columns(conn, "tblAcdQuizResult")
        except Exception:
            return {"items": []}
        if not {"Updated_at", "QuizID", "Score", "StdNo"}.issubset(cols):
            return {"items": []}
        has_person = "PersonNo" in cols

        where = [
            "Updated_at >= :start",
            "Updated_at < DATE_ADD(:end, INTERVAL 1 DAY)",
        ]
        params: dict[str, object] = {"start": start, "end": end}
        if quizId is not None:
            where.append("QuizID = :qid")
            params["qid"] = int(quizId)
        if has_person:
            where.append("PersonNo = :uid")
            params["uid"] = int(user_id)

        sql = text(f"""
            SELECT DATE(Updated_at) AS d,
                   COUNT(*) AS updates,
                   SUM(CASE WHEN Score IS NOT NULL THEN 1 ELSE 0 END) AS scored,
                   COUNT(DISTINCT StdNo) AS students
            FROM tblAcdQuizResult
            WHERE {' AND '.join(where)}
            GROUP BY DATE(Updated_at)
            ORDER BY d
        """)
        rows = conn.execute(sql, params).mappings().all()

    # คืนรูปแบบที่อ่านง่าย
    items = []
    for r in rows:
        d = r.get("d")
        d_str = d.isoformat() if hasattr(d, "isoformat") else str(d)
        items.append({
            "day": d_str,
            "updates": int(r.get("updates") or 0),
            "scored": int(r.get("scored") or 0),
            "students": int(r.get("students") or 0),
        })
    return {"items": items}


@router.get("/daily_breakdown", summary="สรุปรายวันแบบแยกชุดข้อสอบ")
def daily_breakdown(
    day: str = Query(..., description="YYYY-MM-DD"),
    user_id: int = Depends(get_user_id),
):
    """
    คืนรายละเอียดจำนวนอัปเดตรายวัน แยกตามชุดข้อสอบ
    - รวมชื่อชุดจาก tblAcdQuiz
    - กรอง PersonNo หากมีคอลัมน์
    """
    with engine.connect() as conn:
        if not _table_exists(conn, "tblAcdQuizResult"):
            return {"items": []}
        try:
            cols = _table_columns(conn, "tblAcdQuizResult")
        except Exception:
            return {"items": []}
        if not {"Updated_at", "QuizID", "Score"}.issubset(cols):
            return {"items": []}
        has_person = "PersonNo" in cols

        where = [
            "DATE(qr.Updated_at) = :d",
        ]
        params = {"d": day}
        if has_person:
            where.append("qr.PersonNo = :uid")
            params["uid"] = int(user_id)

        sql = text(f"""
            SELECT qr.QuizID AS quizId,
                   q.QuizTitle AS title,
                   COUNT(*) AS updates,
                   SUM(CASE WHEN qr.Score IS NOT NULL THEN 1 ELSE 0 END) AS scored
            FROM tblAcdQuizResult qr
            LEFT JOIN tblAcdQuiz q ON q.QuizID = qr.QuizID
            WHERE {' AND '.join(where)}
            GROUP BY qr.QuizID, q.QuizTitle
            ORDER BY updates DESC, scored DESC
        """)
        rows = conn.execute(sql, params).mappings().all()

    items = []
    for r in rows:
        items.append({
            "quizId": int(r.get("quizId") or 0),
            "title": r.get("title") or "—",
            "updates": int(r.get("updates") or 0),
            "scored": int(r.get("scored") or 0),
        })
    return {"items": items}

@router.get("/summary", summary="สรุปชุดข้อสอบของฉัน (อิง tblAcdQuiz.PersonNo)")
def exams_summary(user_id: int = Depends(get_user_id)):
    sql = text("""
        SELECT COUNT(*) AS sets,
               COALESCE(SUM(COALESCE(ScoreTotal,0)), 0) AS total_questions
        FROM tblAcdQuiz
        WHERE PersonNo = :uid
          AND (IsUse IS NULL OR IsUse = 1)
    """)
    with engine.connect() as conn:
        row = conn.execute(sql, {"uid": user_id}).mappings().first()
    return {
        "sets": int(row["sets"] or 0),
        "total_questions": int(row["total_questions"] or 0),
    }

@router.get("/mine", summary="รายการข้อสอบของฉัน (อิง tblAcdQuiz.PersonNo)")
def exams_mine(
    limit: int = Query(100, ge=1, le=500),
    user_id: int = Depends(get_user_id),
):
    sql = text("""
      SELECT
        q.QuizID   AS id,
        q.QuizTitle AS title,
        q.QuizKind  AS quizKind,  
        q.SubjectNo AS subjectNo,
        subj.SubjectName AS subjectName,
        q.Term AS term,
        q.Year AS year,
        q.ScoreTotal AS total,
        q.PassPercent AS ppercent,
        COALESCE(q.Updated_at, q.Created_at) AS updatedAt
      FROM tblAcdQuiz q
      LEFT JOIN tblAcdSubject subj ON subj.SubjectNo = q.SubjectNo
      WHERE q.PersonNo = :uid
        AND (q.IsUse IS NULL OR q.IsUse = 1)
      ORDER BY COALESCE(q.Updated_at, q.Created_at) DESC, q.QuizID DESC
      LIMIT :lim
    """).bindparams(bindparam("lim", type_=Integer))  # ✅ bind เป็น int

    with engine.connect() as conn:
        rows = conn.execute(sql, {"uid": user_id, "lim": int(limit)}).mappings().all()
    return {"items": rows}

@router.post("", summary="สร้าง/บันทึกชุดข้อสอบ (เขียนที่ tblAcdQuiz)")
def create_exam(payload: CreateExamReq = Body(...),
                user_id: int = Depends(get_user_id)):

    pp = payload.ppercent
    if pp is not None and not (0.0 <= pp <= 100.0):
        raise HTTPException(status_code=422, detail="ppercent must be between 0 and 100")

    # บังคับ whitelist ให้ quizKind ปลอดภัย
    allowed_kinds = {"Pretest","Posttest","Midterm","Final","Other"}
    qk = (payload.quizKind or "Pretest").strip()
    if qk not in allowed_kinds:
        qk = "Other"

    upsert_sql = text("""
        INSERT INTO tblAcdQuiz
          (QuizTitle, QuizKind, SubjectNo, Term, Year, ScoreTotal, PassPercent, PersonNo, TypSubject, Created_at, Updated_at, IsUse, `Type`)
        VALUES
          (:title, :quizKind, :subjectNo, :term, :year, :total, :ppercent, :owner, COALESCE(:typSubject,'Subject'), NOW(), NOW(), 1, 1)
        ON DUPLICATE KEY UPDATE
          ScoreTotal   = VALUES(ScoreTotal),
          PassPercent  = VALUES(PassPercent),
          QuizKind     = VALUES(QuizKind),
          TypSubject   = COALESCE(VALUES(TypSubject), TypSubject),
          Updated_at   = NOW(),
          IsUse        = 1
    """)

    fetch_sql = text("""
      SELECT
        q.QuizID AS id, q.QuizTitle AS title, q.QuizKind AS quizKind,
        q.SubjectNo AS subjectNo, subj.SubjectName AS subjectName,
        q.Term AS term, q.Year AS year, q.ScoreTotal AS total,
        q.PassPercent AS ppercent, q.Created_at AS createdAt
      FROM tblAcdQuiz q
      LEFT JOIN tblAcdSubject subj ON subj.SubjectNo = q.SubjectNo
      WHERE q.SubjectNo=:subjectNo AND q.Term=:term AND q.Year=:year
        AND q.QuizTitle=:title AND q.PersonNo=:owner
      ORDER BY q.QuizID DESC LIMIT 1
    """)

    with engine.begin() as conn:
        conn.execute(upsert_sql, {
            "title": payload.title,
            "quizKind": qk,                                # ✅ ใหม่
            "subjectNo": payload.subjectNo,
            "term": payload.term,
            "year": payload.year,
            "total": payload.total,
            "ppercent": pp,
            "owner": user_id,
            "typSubject": payload.typSubject,              # ✅ รองรับ
        })
        row = conn.execute(fetch_sql, {
            "title": payload.title,
            "subjectNo": payload.subjectNo,
            "term": payload.term,
            "year": payload.year,
            "owner": user_id,
        }).mappings().first()

    return {"ok": True, "item": row}

# ---------- Helpers for /latest counts (เพิ่มเท่าที่จำเป็น) ----------
def _count_candidates(conn, class_list: list[str]) -> int:
    """
    นับจำนวนนักเรียนทั้งหมดที่อยู่ในห้องที่ระบุ (distinct StdNo)
    """
    if not class_list:
        return 0
    try:
        cols = _table_columns(conn, "tblRegStudentRoom")
        if not {"StdNo", "ClassNo"}.issubset(cols):
            return 0
    except Exception:
        return 0
    in_keys = {f"c{i}": c for i, c in enumerate(class_list)}
    in_clause = ", ".join([f":{k}" for k in in_keys.keys()])
    sql = text(f"""
        SELECT COUNT(DISTINCT rs.StdNo) AS total
        FROM tblRegStudentRoom rs
        WHERE rs.ClassNo IN ({in_clause})
    """)
    row = conn.execute(sql, {**in_keys}).mappings().first()
    return int(row["total"] or 0)

def _count_checked(conn, quiz_id: int, class_list: list[str]) -> int:
    """
    นับจำนวนคนที่ 'ตรวจแล้ว' (มีผลคะแนนใน tblAcdQuizResult)
    ถ้ามี class_list จะจำกัดเฉพาะ StdNo ในห้องนั้น
    """
    if class_list:
        try:
            result_cols = _table_columns(conn, "tblAcdQuizResult")
            room_cols = _table_columns(conn, "tblRegStudentRoom")
            if not {"QuizID", "StdNo"}.issubset(result_cols):
                return 0
            if not {"StdNo", "ClassNo"}.issubset(room_cols):
                return 0
        except Exception:
            return 0
        in_keys = {f"c{i}": c for i, c in enumerate(class_list)}
        in_clause = ", ".join([f":{k}" for k in in_keys.keys()])
        sql = text(f"""
            SELECT COUNT(DISTINCT qr.StdNo) AS checked
            FROM tblAcdQuizResult qr
            JOIN tblRegStudentRoom rs ON rs.StdNo = qr.StdNo
            WHERE qr.QuizID = :qid AND rs.ClassNo IN ({in_clause})
        """)
        row = conn.execute(sql, {"qid": quiz_id, **in_keys}).mappings().first()
        return int(row["checked"] or 0)
    else:
        # ไม่มีรายชื่อห้อง -> นับทั้งหมดที่มีผลคะแนนสำหรับควิซนี้
        try:
            result_cols = _table_columns(conn, "tblAcdQuizResult")
            if "QuizID" not in result_cols:
                return 0
        except Exception:
            return 0
        sql = text("""
            SELECT COUNT(*) AS checked
            FROM tblAcdQuizResult
            WHERE QuizID = :qid
        """)
        row = conn.execute(sql, {"qid": quiz_id}).mappings().first()
        return int(row["checked"] or 0)

@router.get("/latest", summary="รายการล่าสุด")
def exams_latest(limit: int = Query(5, ge=1, le=50),
                 user_id: int = Depends(get_user_id)):
    with engine.connect() as conn:
        quiz_cols = _table_columns(conn, "tblAcdQuiz")
        selected = [
            "q.QuizID AS quizId",
            "q.QuizTitle AS title",
            "q.QuizKind AS quizKind" if "QuizKind" in quiz_cols else "NULL AS quizKind",
            "q.Term AS term" if "Term" in quiz_cols else "NULL AS term",
            "q.Year AS year" if "Year" in quiz_cols else "NULL AS year",
            "q.ForClassRoom AS forClassRoom" if "ForClassRoom" in quiz_cols else "NULL AS forClassRoom",
        ]
        if {"Updated_at", "Created_at"}.issubset(quiz_cols):
            selected.append("COALESCE(q.Updated_at, q.Created_at) AS _dt")
            order_by = "_dt DESC"
        elif "Updated_at" in quiz_cols:
            selected.append("q.Updated_at AS _dt")
            order_by = "_dt DESC"
        elif "Created_at" in quiz_cols:
            selected.append("q.Created_at AS _dt")
            order_by = "_dt DESC"
        else:
            selected.append("NULL AS _dt")
            order_by = "q.QuizID DESC"

        where = []
        params: dict[str, object] = {"lim": int(limit)}
        if "PersonNo" in quiz_cols:
            where.append("q.PersonNo = :uid")
            params["uid"] = int(user_id)
        if "IsUse" in quiz_cols:
            where.append("(q.IsUse IS NULL OR q.IsUse = 1)")
        where_sql = f"WHERE {' AND '.join(where)}" if where else ""

        sql = text(f"""
          SELECT {", ".join(selected)}
          FROM tblAcdQuiz q
          {where_sql}
          ORDER BY {order_by}
          LIMIT :lim
        """).bindparams(bindparam("lim", type_=Integer))

        rows = conn.execute(sql, params).mappings().all()

        items = []
        for r in rows:
            qid = int(r.get("quizId") or 0)
            dt = r.get("_dt")
            dt_str = dt.isoformat(sep=" ", timespec="seconds") if hasattr(dt, "isoformat") else (str(dt) if dt else "")
            class_list = _parse_class_list(r.get("forClassRoom"))

            if class_list:
                total = _count_candidates(conn, class_list)
                checked = _count_checked(conn, qid, class_list)
                pending = max(0, total - checked)
            else:
                # ไม่ทราบจำนวนทั้งหมด -> คืนเฉพาะ checked; total/pending เป็น None
                checked = _count_checked(conn, qid, [])
                total = None
                pending = None

            items.append({
                "scoreId": r.get("quizId"),   # compat เดิม
                "quizId":  r.get("quizId"),
                "title":   r.get("title") or "—",
                "quizKind": r.get("quizKind"),
                "term":    r.get("term") or "",
                "year":    r.get("year") or "",
                "createdAt": dt_str,
                # ✅ เพิ่มสำหรับหน้า Home: เหลือยังไม่ตรวจ ฯลฯ
                "totalCandidates": total,
                "checkedCount": checked,
                "pendingCount": pending,
            })
    return {"items": items}

@router.get("/results", summary="ผลควิซรวมหลายห้อง (ชื่อ+คะแนน+สถานะ)")
def quiz_results(
    quizId: int = Query(...),
    term: int = Query(...),
    year: int = Query(...),
    classNos: str | None = Query(None),
    _: int = Depends(get_user_id),
):
    # 1) ดึงหัวควิซ
    sql_quiz = text("""
        SELECT QuizID, QuizTitle, SubjectNo, ForClassRoom, Term, Year, ScoreTotal, PassPercent
        FROM tblAcdQuiz
        WHERE QuizID = :qid
        LIMIT 1
    """)
    with engine.connect() as conn:
        q = conn.execute(sql_quiz, {"qid": quizId}).mappings().first()
        if not q:
            raise HTTPException(status_code=404, detail="Quiz not found")

    # คำนวณเกณฑ์ก่อนเลย เผื่อคืนผลแบบ items ว่าง
    score_total  = int(q.get("ScoreTotal") or 0)
    pass_percent = float(q.get("PassPercent") or 0.0)
    pass_score   = round(score_total * (pass_percent / 100.0)) if pass_percent else 0

    # 2) ห้องเรียนจากพารามิเตอร์หรือ ForClassRoom
    class_list = _parse_class_list(classNos) or _parse_class_list(q.get("ForClassRoom"))

    # ✅ ถ้าไม่มีห้อง ให้คืน 200 + items ว่าง (Flutter จะโชว์หัวตาราง + “ไม่พบรายชื่อ”)
    if not class_list:
        return {
            "quiz": {
                "title":       q.get("QuizTitle"),
                "subjectNo":   q.get("SubjectNo"),
                "classNos":    [],
                "term":        term,
                "year":        year,
                "scoreTotal":  score_total,
                "passPercent": pass_percent,
                "passScore":   pass_score,
            },
            "items": [],
        }

    # 3) ดึงรายชื่อ+คะแนนตามห้อง (เหมือนเดิม)
    in_keys = {f"c{i}": c for i, c in enumerate(class_list)}
    in_clause = ", ".join([f":{k}" for k in in_keys.keys()])

    sql_items = text(f"""
    SELECT
        rs.StdNo AS stdNo,
        COALESCE(CONCAT_WS(' ', st.FName, st.LName), rs.StdNo) AS name,
        qr.Score AS score,
        rs.rYear AS rYear,
        rs.Room  AS room
    FROM tblRegStudentRoom rs
    LEFT JOIN tblRegStudent st
      ON st.StdNo = rs.StdNo
    LEFT JOIN tblAcdQuizResult qr
      ON qr.QuizID = :qid AND qr.StdNo = rs.StdNo
    WHERE rs.ClassNo IN ({in_clause})
    GROUP BY rs.StdNo, name, rs.rYear, rs.Room, qr.Score
    ORDER BY rs.StdNo
""")

    with engine.connect() as conn:
        rows = conn.execute(sql_items, {"qid": quizId, "term": term, "year": year, **in_keys}).mappings().all()

    items = []
    for r in rows:
        sc = r.get("score")
        checked = sc is not None
        items.append({
            "stdNo":   r.get("stdNo"),
            "name":    r.get("name") or r.get("stdNo"),
            "score":   int(sc) if sc is not None else None,
            "checked": bool(checked),
            "rYear":   (r.get("rYear") if r.get("rYear") is None else int(r.get("rYear"))),
            "room":    (r.get("room")  if r.get("room")  is None else int(r.get("room"))),
            "status":  "ตรวจแล้ว" if checked else "ยังไม่ตรวจ",
        })

    return {
        "quiz": {
            "title":       q.get("QuizTitle"),
            "subjectNo":   q.get("SubjectNo"),
            "classNos":    class_list,
            "term":        term,
            "year":        year,
            "scoreTotal":  score_total,
            "passPercent": pass_percent,
            "passScore":   pass_score,
        },
        "items": items,  # 6 ช่องหลัก: stdNo, name, score, checked, rYear, room
    }

@router.get("/result", summary="ผลสอบของนักเรียนรายคน (แนบรูป Base64 ถ้ามี)")
def get_result_detail(
    quizId: int = Query(...),
    stdNo: str = Query(...),
    includeImage: int = Query(1, ge=0, le=1),
    _: int = Depends(get_user_id),
):
    sql = text(
        """
        SELECT
            qr.QuizID        AS quizId,
            qr.StdNo         AS stdNo,
            qr.Score         AS score,
            qr.ImageBase64   AS imageBase64,
            qr.CheckedAt     AS checkedAt,
            qr.GradedBy      AS gradedBy,

            q.QuizTitle      AS title,
            q.SubjectNo      AS subjectNo,
            q.ScoreTotal     AS scoreTotal,
            q.PassPercent    AS passPercent,

            st.FName         AS fName,
            st.LName         AS lName
        FROM tblAcdQuizResult qr
        LEFT JOIN tblAcdQuiz q ON q.QuizID = qr.QuizID
        LEFT JOIN tblRegStudent st ON st.StdNo = qr.StdNo
        WHERE qr.QuizID = :qid AND qr.StdNo = :std
        LIMIT 1
        """
    )
    with engine.connect() as conn:
        row = conn.execute(sql, {"qid": quizId, "std": stdNo}).mappings().first()
        if not row:
            raise HTTPException(status_code=404, detail="Result not found")

    score_total = int(row.get("scoreTotal") or 0)
    pass_percent = float(row.get("passPercent") or 0.0)
    pass_score = round(score_total * (pass_percent / 100.0)) if pass_percent else 0

    full_name = (f"{(row.get('fName') or '').strip()} {(row.get('lName') or '').strip()}" ).strip()
    data = {
        "quizId": int(row.get("quizId") or quizId),
        "stdNo": str(row.get("stdNo") or stdNo),
        "studentName": full_name or row.get("stdNo") or stdNo,
        "score": int(row.get("score") or 0),
        "total": score_total,
        "passScore": pass_score,
        "title": row.get("title"),
        "subjectNo": row.get("subjectNo"),
        "checkedAt": (row.get("checkedAt").isoformat(sep=" ", timespec="seconds")
                       if hasattr(row.get("checkedAt"), "isoformat") and row.get("checkedAt") is not None
                       else (str(row.get("checkedAt")) if row.get("checkedAt") is not None else None)),
        "gradedBy": row.get("gradedBy"),
    }
    if includeImage == 1:
        data["imageBase64"] = row.get("imageBase64")
    return data

@router.get("/choices")
def get_choices(quizId: int, _: int = Depends(get_user_id)):
    sql = text("""
      SELECT
        No               AS no,
        Choice_1         AS c1,
        Choice_2         AS c2,
        Choice_3         AS c3,
        Choice_4         AS c4,
        Choice_5         AS c5,
        Answer           AS answer,     -- 1..5
        Score            AS score,      -- จะกำหนดเป็น 1 ทุกข้อก็ได้
        COALESCE(IsUse,1) AS isUse
      FROM tblAcdQuizChoice
      WHERE QuizID = :qid
      ORDER BY No
    """)
    with engine.connect() as conn:
        rows = conn.execute(sql, {"qid": quizId}).mappings().all()
    # map เป็น ก ข ค ง จ เพื่อ UI
    for r in rows:
        r = dict(r)
        r["answerLetter"] = ["ก","ข","ค","ง","จ"][max(1, min(5, int(r["answer"] or 0)))-1]
        yield r

@router.put("/choice/{quizId}/{no}")
def update_choice(
    quizId: int, no: int,
    payload: dict = Body(...), _: int = Depends(get_user_id)
):
    # payload รองรับ: answer(1..5), c1..c5, score, isUse
    sql = text("""
      UPDATE tblAcdQuizChoice
      SET
        Choice_1 = COALESCE(:c1, Choice_1),
        Choice_2 = COALESCE(:c2, Choice_2),
        Choice_3 = COALESCE(:c3, Choice_3),
        Choice_4 = COALESCE(:c4, Choice_4),
        Choice_5 = COALESCE(:c5, Choice_5),
        Answer   = COALESCE(:answer, Answer),
        Score    = COALESCE(:score, Score),
        IsUse    = COALESCE(:isUse, IsUse),
        Updated_at = NOW()
      WHERE QuizID = :qid AND `No` = :no
    """)
    with engine.begin() as conn:
        n = conn.execute(sql, {
            "qid": quizId, "no": no,
            "c1": payload.get("c1"), "c2": payload.get("c2"),
            "c3": payload.get("c3"), "c4": payload.get("c4"),
            "c5": payload.get("c5"),
            "answer": payload.get("answer"),
            "score": payload.get("score"),
            "isUse": payload.get("isUse"),
        }).rowcount
    if n == 0:
        raise HTTPException(404, "Choice not found")
    return {"ok": True}
