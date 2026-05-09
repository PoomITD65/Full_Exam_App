# api/routers/omr.py
from fastapi import APIRouter, UploadFile, File, HTTPException, Form, Depends
from fastapi.responses import FileResponse, HTMLResponse
from typing import Dict, Any, Tuple
import base64
from datetime import datetime
from pathlib import Path
import uuid

import numpy as np
import cv2

TOTAL_OMR_QUESTIONS = 80

# เราใช้ logic จากบริการ OMR ที่อยู่ในโฟลเดอร์ typhoon-grader
# โดย import ฟังก์ชันหลักมาใช้โดยตรง เพื่อให้ระบบรันรวมอยู่พอร์ตเดียวกับ FastAPI
try:
    from typhoon_grader_app import omr_process, load_answer_key, REPORTS_DIR, ANSWER_KEY_FILE
except Exception:
    # รองรับ path แบบเดิม "backend/typhoon-grader/app.py"
    # import ตรงจากไฟล์ app.py
    import importlib.util
    TG_PATH = Path(__file__).resolve().parents[2] / "typhoon-grader" / "app.py"
    spec = importlib.util.spec_from_file_location("tg_app", str(TG_PATH))
    assert spec and spec.loader, "Cannot import typhoon-grader/app.py"
    tg = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tg)  # type: ignore
    omr_process = getattr(tg, "omr_process")
    load_answer_key = getattr(tg, "load_answer_key")
    REPORTS_DIR = getattr(tg, "REPORTS")
    ANSWER_KEY_FILE = getattr(tg, "ANSWER_KEY_FILE")
    TEMPLATES_DIR = getattr(tg, "TEMPLATES", None)

router = APIRouter()
from core.db import engine
from core.security import get_user_id


def _load_answer_key_from_db(quiz_id: int) -> Tuple[Dict[str, str], int]:
    """
    โหลดเฉลยจาก tblAcdQuizChoice ตาม QuizID
    แปลง Answer (1..5) เป็นตัวเลือก A..E ให้ตรงกับผลจาก OMR
    คืน (key, score_per_question)
    """
    from sqlalchemy import text

    key: Dict[str, str] = {}
    spq = 1

    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    """
                    SELECT
                      `No`        AS no,
                      Answer      AS answer,
                      Score       AS score,
                      COALESCE(IsUse, 1) AS isUse
                    FROM tblAcdQuizChoice
                    WHERE QuizID = :qid
                    ORDER BY `No`
                    """
                ),
                {"qid": int(quiz_id)},
            ).mappings().all()
    except Exception:
        return key, spq

    scores: list[int] = []
    for r in rows:
        try:
            if int(r.get("isUse") or 0) != 1:
                continue
            no = int(r.get("no") or 0)
            ans_idx = int(r.get("answer") or 0)
            if not (1 <= no <= TOTAL_OMR_QUESTIONS and 1 <= ans_idx <= 5):
                continue
            letter = "ABCDE"[ans_idx - 1]
            key[f"Q{no}"] = letter
            sc_val = r.get("score")
            if sc_val is not None:
                scores.append(int(sc_val))
        except Exception:
            continue

    if scores:
        # ถ้าคะแนนต่อข้อไม่เท่ากัน ให้ใช้ 1 เป็นค่า default
        spq_candidate = scores[0]
        if all(s == spq_candidate for s in scores):
            spq = int(spq_candidate)

    return key, spq


def _persist_result(
    *,
    quiz_id: int,
    term: str | int,
    year: str | int,
    std_no: str,
    score: int,
    user_id: int,
    grader: str | None,
    image_base64: str | None = None,
) -> Dict[str, Any]:
    from sqlalchemy import text

    out: Dict[str, Any] = {}
    try:
        sql_chk = text(
            """
            SELECT SubjectNo, Term, Year
            FROM tblAcdQuiz
            WHERE QuizID = :qid
            LIMIT 1
            """
        )

        term_str = str(term)
        year_str = str(year)

        with engine.begin() as conn:
            db_info = conn.execute(text("SELECT DATABASE() AS db, @@hostname AS host")).mappings().first()
            if db_info:
                out["db_name"], out["db_host"] = db_info.get("db"), db_info.get("host")

            row = conn.execute(sql_chk, {"qid": int(quiz_id)}).mappings().first()
            if not row:
                out.update({"saved": False, "reason": "quiz-not-found"})
                return out

            r = dict(row)
            subject_no = r.get("SubjectNo")
            term_db = r.get("Term")
            year_db = r.get("Year")
            term_str = str(term_db or term_str)
            year_str = str(year_db or year_str)
            out["quiz_header"] = {"subjectNo": subject_no, "term": term_str, "year": year_str}

            col_rows = conn.execute(text("SHOW COLUMNS FROM tblAcdQuizResult")).mappings().all()
            existing = {r["Field"] for r in col_rows}

            def _is_generated(col_name: str) -> bool:
                for r in col_rows:
                    if r.get("Field") == col_name:
                        extra = (r.get("Extra") or "").lower()
                        return "generated" in extra
                return False

            insert_cols: list[str] = []
            values_expr: list[str] = []
            params: dict[str, object] = {}

            def bind(col: str, val: object):
                insert_cols.append(f"`{col}`")
                values_expr.append(f":{col}")
                params[col] = val

            def const(col: str, expr: str):
                insert_cols.append(f"`{col}`")
                values_expr.append(expr)

            if "QuizID" in existing: bind("QuizID", int(quiz_id))
            if "StdNo" in existing:
                try:
                    bind("StdNo", int(std_no))
                except Exception:
                    bind("StdNo", std_no)
            if "Score" in existing: bind("Score", int(score))
            if "SubjectNo" in existing and subject_no is not None: bind("SubjectNo", subject_no)
            if "Term" in existing: bind("Term", term_str)
            if "Year" in existing: bind("Year", year_str)
            if "PersonNo" in existing: bind("PersonNo", int(user_id))
            if "GradedBy" in existing: bind("GradedBy", grader or str(user_id))
            if "ImageBase64" in existing and image_base64:
                bind("ImageBase64", image_base64)
            if "Status" in existing and not _is_generated("Status"):
                const("Status", "1")
            if "CheckedAt" in existing and not _is_generated("CheckedAt"):
                const("CheckedAt", "NOW()")
            if "IsUse" in existing: const("IsUse", "1")
            if "Created_at" in existing: const("Created_at", "NOW()")
            if "Updated_at" in existing: const("Updated_at", "NOW()")

            provided = {c.strip("`") for c in insert_cols}
            for r in col_rows:
                fld = r.get("Field")
                if not fld or fld in provided:
                    continue
                extra_val = (r.get("Extra") or "").lower()
                if ("auto_increment" in extra_val) or ("generated" in extra_val):
                    continue
                if (r.get("Null") == "YES") or (r.get("Default") is not None):
                    continue
                t = (r.get("Type") or "").lower()
                if any(x in t for x in ["int", "tinyint", "smallint", "bigint"]):
                    bind(fld, 0)
                elif any(x in t for x in ["decimal", "float", "double", "numeric"]):
                    bind(fld, 0)
                elif "datetime" in t or "timestamp" in t:
                    const(fld, "NOW()")
                elif "date" in t:
                    bind(fld, "1970-01-01")
                else:
                    bind(fld, "")

            if not insert_cols:
                out.update({"saved": False, "reason": "no-columns"})
                return out

            update_parts: list[str] = []
            if "Score" in existing:
                update_parts.append("`Score` = VALUES(`Score`)")
            if "ImageBase64" in existing and image_base64:
                update_parts.append("`ImageBase64` = VALUES(`ImageBase64`)")
            if "Updated_at" in existing:
                update_parts.append("`Updated_at` = NOW()")

            upsert_sql = f"""
                INSERT INTO tblAcdQuizResult ({', '.join(insert_cols)})
                VALUES ({', '.join(values_expr)})
                ON DUPLICATE KEY UPDATE {', '.join(update_parts) if update_parts else '`Score`=`Score`'}
            """

            res = conn.execute(text(upsert_sql), params)
            out["db_affected"] = int(getattr(res, "rowcount", 0))
            out["db_insert_columns"] = insert_cols
            out["subject_no"] = subject_no
            out["db_sql_preview"] = {
                "sql": " ".join(upsert_sql.split()).strip()[:400],
                "params": {k: ("<bytes>" if isinstance(v, (bytes, bytearray)) else v) for k, v in params.items()},
            }

            verify_sql = text(
                """
                SELECT QuizID, StdNo, Score, Updated_at
                FROM tblAcdQuizResult
                WHERE QuizID = :qid AND StdNo = :std
                ORDER BY Updated_at DESC LIMIT 1
                """
            )
            v = conn.execute(verify_sql, {"qid": int(quiz_id), "std": params.get("StdNo", std_no)}).mappings().first()
            out["db_verify"] = dict(v) if v else None
            out["saved"] = bool(v)
            return out
    except Exception as e:
        out.update({"saved": False, "reason": "db-error", "error": str(e)})
        return out

@router.get("/", summary="OMR home")
def omr_home():
    # ถ้ามีไฟล์ templates/index.html ของบริการเดิม ให้คืน HTML ตรง ๆ
    try:
        if 'TEMPLATES_DIR' in globals() and TEMPLATES_DIR is not None:
            idx = Path(TEMPLATES_DIR) / "index.html"
            if idx.exists():
                return HTMLResponse(idx.read_text(encoding="utf-8"))
    except Exception:
        pass
    # fallback เป็นข้อความสั้น ๆ
    return {"message": "OMR Service is running. POST /omr/grade with an image file."}

@router.post("/grade", summary="Grade OMR sheet (upload image)")
async def grade_omr(
    file: UploadFile = File(...),
    quizId: int = Form(...),
    term: int | str = Form(...),
    year: int | str = Form(...),
    grader: str | None = Form(None),
    user_id: int = Depends(get_user_id),
) -> Dict[str, Any]:
    try:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="empty-file")

        # decode image from bytes
        data = np.frombuffer(content, dtype=np.uint8)
        img = cv2.imdecode(data, cv2.IMREAD_COLOR)
        if img is None:
            raise HTTPException(status_code=400, detail="invalid-image")

        # โหลดเฉลยจากฐานข้อมูลตาม QuizID (ใช้ทั้งสำหรับวาด debug และคำนวณคะแนน)
        key, spq = _load_answer_key_from_db(int(quizId))

        # run detector โดยส่ง key จากฐานข้อมูลเข้าไปให้ใช้ในการวาดถูก/ผิด
        omr, dbg = omr_process(img, key)

        # save debug image to reports folder
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)
        ext = Path(file.filename or "").suffix.lower() or ".jpg"
        fname = f"{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex}_debug{ext}"
        out_path = REPORTS_DIR / fname
        cv2.imwrite(str(out_path), dbg)

        # make compact base64 for DB (resize + jpeg quality)
        def _to_b64(img) -> str:
            try:
                h, w = img.shape[:2]
                max_w = 800
                if w > max_w:
                    scale = max_w / float(w)
                    img = cv2.resize(img, (int(w*scale), int(h*scale)))
                ok, enc = cv2.imencode('.jpg', img, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
                if not ok:
                    return ""
                return base64.b64encode(enc.tobytes()).decode('ascii')
            except Exception:
                return ""
        img_b64 = _to_b64(dbg)

        answers = omr.get("answers", {}) or {}

        # ใช้จำนวนข้อจากเฉลยจริง ๆ แทนที่จะ fix จำนวนข้อ
        if key:
            keyed_numbers: list[int] = []
            for k in key.keys():
                if isinstance(k, str) and k.startswith("Q"):
                    num_str = k[1:]
                    if num_str.isdigit():
                        n = int(num_str)
                        if 1 <= n <= TOTAL_OMR_QUESTIONS:
                            keyed_numbers.append(n)
            keyed_numbers = sorted(set(keyed_numbers))
            total_questions = len(keyed_numbers)
        else:
            keyed_numbers = []
            total_questions = 0

        total = (total_questions * spq) if key and total_questions > 0 else None

        details: list[dict[str, object]] = []
        cnt_correct = 0
        answered_count = 0

        for i in range(1, TOTAL_OMR_QUESTIONS + 1):
            q = f"Q{i}"
            selected = answers.get(q)
            correct = key.get(q) if key else None
            in_key = correct is not None  # มีเฉลยสำหรับข้อนี้หรือไม่

            # ตรวจเฉพาะข้อที่มีในเฉลยจริง ๆ
            is_ok = bool(
                in_key
                and selected is not None
                and selected == correct
            )

            # นับจำนวนข้อที่ตอบเฉพาะข้อที่มีในเฉลย
            if in_key and selected not in (None, "N/A"):
                answered_count += 1

            if is_ok:
                cnt_correct += 1

            # กำหนดสถานะและคะแนนต่อข้อ:
            # - ถ้ามีเฉลย: ให้คะแนน spq เมื่อถูก, 0 เมื่อผิด
            # - ถ้าไม่มีเฉลย แต่มีการฝน (ฝนเกินจากข้อที่กำหนด): ถือว่า "ผิด" แต่ไม่ให้คะแนนเพิ่ม
            if key:
                if in_key:
                    is_correct_flag = is_ok
                    points = spq if is_ok else 0
                else:
                    # ไม่มีเฉลยข้อนี้
                    if selected is not None:
                        # ฝนเกินจากข้อที่มีในเฉลย -> นับเป็นผิด แต่คะแนน 0
                        is_correct_flag = False
                        points = 0
                    else:
                        is_correct_flag = None
                        points = None
            else:
                is_correct_flag = None
                points = None

            details.append({
                "q": i,
                "selected": selected,
                "correct": correct,
                "isCorrect": is_correct_flag,
                "points": points,
            })

        score = (cnt_correct * spq) if key and total_questions > 0 else None

        result: Dict[str, Any] = {
            "student_id": omr.get("student_id"),
            "student_id_valid": omr.get("student_id_valid", True),
            "student_id_warnings": omr.get("student_id_warnings", []),
            "answers": answers,
            "score": score,
            "total": total,
            "total_questions": total_questions or 0,
            "answered_count": answered_count,
            "correct_count": cnt_correct if key else None,
            "points_per_question": spq if key else None,
            "per_question": details,  # list: [{q, selected, correct, isCorrect, points}]
            "debug_image": f"/omr/reports/{fname}",
        }

        # ===== Persist result to database (tblAcdQuizResult) =====
        std_no = (omr.get("student_id") or "").strip()
        if not omr.get("student_id_valid", True):
            result["saved"] = False
            result["reason"] = "invalid-student-id"
            return result
        if not std_no:
            # ไม่ทราบรหัสนักเรียน -> ส่งคืนผลคำนวณ แต่ไม่บันทึก DB
            result["saved"] = False
            result["reason"] = "missing-student-id"
            return result

        # ตรวจสอบว่ารหัสนักเรียนนี้มีอยู่ในระบบหรือไม่ (tblRegStudent)
        # รองรับกรณีมี/ไม่มีเลข 0 นำหน้า โดยลองทั้งแบบเดิมและแบบตัด 0 ด้านซ้าย
        try:
            from sqlalchemy import text as _sql_text

            std_trim = std_no.strip()
            std_no_nolead = std_trim.lstrip("0") or std_trim

            sql_chk_std = """
                SELECT 1
                FROM tblRegStudent
                WHERE StdNo = :std
                   OR StdNo = :std_nolead
                LIMIT 1
            """

            with engine.connect() as conn:
                row = conn.execute(
                    _sql_text(sql_chk_std),
                    {"std": std_trim, "std_nolead": std_no_nolead},
                ).first()
        except Exception:
            row = None

        if row is None:
            # รหัสนักศึกษาไม่ถูกต้อง หรือไม่มีในระบบ -> ไม่บันทึก DB
            result["saved"] = False
            result["reason"] = "student-not-found"
            result["message"] = "รหัสนักศึกษาไม่ถูกต้องหรือไม่มีอยู่ในระบบ"
            return result

        if score is None:
            # ไม่มีเฉลย -> ยังไม่สามารถบันทึกคะแนนได้
            result["saved"] = False
            result["reason"] = "no-answer-key"
            return result

        # ใช้ helper บันทึกผลลงฐานข้อมูล แล้วรวมข้อมูลดีบักกลับ และจบงานที่นี่
        persist = _persist_result(
            quiz_id=int(quizId),
            term=term,
            year=year,
            std_no=std_no,
            score=int(score),
            user_id=int(user_id),
            grader=grader,
            image_base64=(img_b64 if img_b64 else None),
        )
        for k, v in persist.items():
            if k not in result:
                result[k] = v
        result["quizId"] = quizId
        result["term"] = term
        result["year"] = year
        if grader:
            result["grader"] = grader
        return result

        from sqlalchemy import text

        try:
            # ตรวจสอบหัวควิซ และดึง SubjectNo (ยึดตาม QuizID เป็นหลัก เพื่อกันความต่างของชนิดข้อมูล Term/Year)
            sql_chk = text(
                """
                SELECT SubjectNo, Term, Year
                FROM tblAcdQuiz
                WHERE QuizID = :qid
                LIMIT 1
                """
            )

            # ทำให้ term/year เป็นสตริงเพื่อเทียบกับสคีมาที่เก็บเป็น VARCHAR
            term_str = str(term)
            year_str = str(year)

            with engine.begin() as conn:
                # ระบุ DB ที่ใช้อยู่ เพื่อดีบัก
                db_info = conn.execute(text("SELECT DATABASE() AS db, @@hostname AS host")).mappings().first()
                if db_info:
                    result["db_name"] = db_info.get("db")
                    result["db_host"] = db_info.get("host")

                row = conn.execute(sql_chk, {"qid": quizId}).mappings().first()
                if not row:
                    # ถ้าควิซไม่พบ ให้ส่งผลคำนวณกลับ โดยไม่บันทึก
                    result["saved"] = False
                    result["reason"] = "quiz-not-found"
                    return result
                subject_no = row.get("SubjectNo") if isinstance(row, dict) else (row[0] if row else None)
                # ปรับ term/year ให้ตรงกับหัวควิซถ้าไม่ตรง เพื่อหลีกเลี่ยง mismatch
                term_db = row.get("Term") if isinstance(row, dict) else None
                year_db = row.get("Year") if isinstance(row, dict) else None
                term_str = str(term_db or term_str)
                year_str = str(year_db or year_str)
                result["quiz_header"] = {"subjectNo": subject_no, "term": term_str, "year": year_str}

                # ดึงคอลัมน์จริงของตาราง + รายละเอียดชนิด/ข้อบังคับ
                col_rows = conn.execute(text("SHOW COLUMNS FROM tblAcdQuizResult")).mappings().all()
                existing = {r["Field"] for r in col_rows}

                insert_cols: list[str] = []
                values_expr: list[str] = []
                params: dict[str, object] = {}

                def bind(col: str, val: object):
                    insert_cols.append(f"`{col}`")
                    values_expr.append(f":{col}")
                    params[col] = val

                def const(col: str, expr: str):
                    insert_cols.append(f"`{col}`")
                    values_expr.append(expr)

                # คอลัมน์หลักที่มักมี
                if "QuizID" in existing: bind("QuizID", int(quizId))
                # StdNo บางฐานเป็น INT: ลองแปลงเป็น int ถ้าเป็นตัวเลขล้วน มิฉะนั้นใช้ string
                if "StdNo" in existing:
                    try:
                        bind("StdNo", int(std_no))
                    except Exception:
                        bind("StdNo", std_no)
                if "Score" in existing: bind("Score", int(score))
                if "SubjectNo" in existing and subject_no is not None: bind("SubjectNo", subject_no)
                if "Term" in existing: bind("Term", term_str)
                if "Year" in existing: bind("Year", year_str)
                if "PersonNo" in existing: bind("PersonNo", int(user_id))
                if "GradedBy" in existing:
                    bind("GradedBy", grader or str(user_id))
                if "Status" in existing:
                    const("Status", "1")
                if "CheckedAt" in existing:
                    const("CheckedAt", "NOW()")
                if "IsUse" in existing: const("IsUse", "1")
                if "Created_at" in existing: const("Created_at", "NOW()")
                if "Updated_at" in existing: const("Updated_at", "NOW()")

                # เติมค่า default สำหรับคอลัมน์ NOT NULL ที่ไม่มี default (กัน error)
                provided = {c.strip("`") for c in insert_cols}
                for r in col_rows:
                    fld = r.get("Field")
                    if not fld or fld in provided:
                        continue
                    # ข้าม AUTO_INCREMENT
                    if (r.get("Extra") or "").lower().find("auto_increment") >= 0:
                        continue
                    # ถ้าอนุญาต NULL หรือมี default แล้วก็ข้าม
                    if (r.get("Null") == "YES") or (r.get("Default") is not None):
                        continue
                    # ใส่ค่าปลอดภัยตามชนิด
                    t = (r.get("Type") or "").lower()
                    if any(x in t for x in ["int", "tinyint", "smallint", "bigint"]):
                        bind(fld, 0)
                    elif any(x in t for x in ["decimal", "float", "double", "numeric"]):
                        bind(fld, 0)
                    elif "datetime" in t or "timestamp" in t:
                        const(fld, "NOW()")
                    elif "date" in t:
                        bind(fld, "1970-01-01")
                    else:
                        # varchar/text/others -> ช่องว่าง
                        bind(fld, "")

                if not insert_cols:
                    raise RuntimeError("tblAcdQuizResult has no expected columns")

                # อัปเดตเมื่อซ้ำ: อย่างน้อย Score และ Updated_at
                update_parts: list[str] = []
                if "Score" in existing:
                    update_parts.append("`Score` = VALUES(`Score`)")
                if "Updated_at" in existing:
                    update_parts.append("`Updated_at` = NOW()")

                upsert_sql = f"""
                    INSERT INTO tblAcdQuizResult ({', '.join(insert_cols)})
                    VALUES ({', '.join(values_expr)})
                    ON DUPLICATE KEY UPDATE {', '.join(update_parts) if update_parts else '`Score`=`Score`'}
                """

                res = conn.execute(text(upsert_sql), params)
                result["db_affected"] = int(getattr(res, "rowcount", 0))
                result["db_insert_columns"] = insert_cols
                result["subject_no"] = subject_no
                # preview SQL/params แบบย่อเพื่อดีบัก
                result["db_sql_preview"] = {
                    "sql": " ".join(upsert_sql.split()).strip()[:400],
                    "params": {k: ("<bytes>" if isinstance(v, (bytes, bytearray)) else v) for k, v in params.items()},
                }

                # ตรวจสอบว่ามีแถวอยู่จริงหลัง upsert
                verify_sql = text("""
                    SELECT QuizID, StdNo, Score, Updated_at
                    FROM tblAcdQuizResult
                    WHERE QuizID = :qid AND StdNo = :std
                    ORDER BY Updated_at DESC LIMIT 1
                """)
                v = conn.execute(verify_sql, {"qid": quizId, "std": params.get("StdNo", std_no)}).mappings().first()
                if v:
                    result["db_verify"] = dict(v)
                    result["saved"] = True
                else:
                    result["db_verify"] = None
                    result["saved"] = False
                    result["reason"] = "verify-failed"
        except Exception as e:
            # อย่าให้ทั้งคำขอพัง — คืนผลพร้อมเหตุผลบันทึกไม่ได้
            result["saved"] = False
            result["reason"] = "db-error"
            result["error"] = str(e)
        result["quizId"] = quizId
        result["term"] = term
        result["year"] = year
        if grader:
            result["grader"] = grader
        return result
    finally:
        await file.close()

@router.get("/reports/{filename}", summary="Serve OMR debug image")
def get_report_image(filename: str):
    f = REPORTS_DIR / filename
    if not f.exists() or not f.is_file():
        raise HTTPException(status_code=404, detail="not-found")
    return FileResponse(str(f))


@router.get("/key", summary="Get current answer key/status")
def get_key():
    key, spq = load_answer_key()
    return {"key": key, "score_per_question": spq}


@router.post("/key", summary="Set answer key (JSON)")
def set_key(payload: Dict[str, Any]):
    try:
        # Expecting: {"key": {"Q1":"A",...}, "score_per_question": 1}
        import json
        Path(ANSWER_KEY_FILE).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ทางเลือกสำหรับ path เดิมของ Flask: /set_answer_key (GET)
@router.get("/set_answer_key", summary="Legacy key form/info")
def get_key_page():
    # ถ้ามีไฟล์ templates/key_form.html ก็คืน HTML ตรง ๆ เหมือนเดิม
    try:
        if 'TEMPLATES_DIR' in globals() and TEMPLATES_DIR is not None:
            f = Path(TEMPLATES_DIR) / "key_form.html"
            if f.exists():
                return HTMLResponse(f.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {"message": "POST /omr/key with JSON: { 'key': { 'Q1':'A', ... }, 'score_per_question': 1 }"}


@router.post("/save", summary="Save graded result (JSON)")
def save_graded_result(payload: Dict[str, Any], user_id: int = Depends(get_user_id)):
    try:
        quiz_id = int(payload.get("quizId") or payload.get("QuizID"))
    except Exception:
        raise HTTPException(422, detail="quizId is required")

    term = payload.get("term") or payload.get("Term") or ""
    year = payload.get("year") or payload.get("Year") or ""
    std = payload.get("student_id") or payload.get("studentId") or payload.get("StdNo")
    if not std:
        raise HTTPException(422, detail="student_id (StdNo) is required")
    try:
        score = int(payload.get("score") or payload.get("Score"))
    except Exception:
        raise HTTPException(422, detail="score is required")
    grader = payload.get("grader") or payload.get("GradedBy")
    image_b64 = payload.get("imageBase64") or payload.get("image_base64") or payload.get("ImageBase64")

    out = _persist_result(
        quiz_id=quiz_id,
        term=term,
        year=year,
        std_no=str(std),
        score=score,
        user_id=int(user_id),
        grader=grader if grader is None or isinstance(grader, str) else str(grader),
        image_base64=(image_b64 if isinstance(image_b64, str) and len(image_b64) > 0 else None),
    )
    out.update({"quizId": quiz_id, "term": term, "year": year, "student_id": str(std), "score": score})
    return out
