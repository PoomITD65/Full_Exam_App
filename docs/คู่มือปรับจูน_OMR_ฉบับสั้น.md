# คู่มือปรับจูน OMR (สั้นและเน้นใช้งานจริง)

เป้าหมาย: จูนพารามิเตอร์ให้การอ่านวงกลม (OMR) เสถียรกับภาพจริง โดยเน้นเฉพาะปุ่มจูนที่ต้องใช้บ่อย พร้อมช่วงค่าแนะนำ อ้างอิงโค้ด `backend/typhoon-grader/app.py`.

## ปุ่มจูนหลัก
- ขยาย ROI หาเส้นจริง: `REFINE_PAD_RATIO` (ค่าเริ่ม 0.018)
  - ใช้เมื่อเส้นกริดซีด/เหลื่อม เพิ่มเป็น 0.020–0.030
- ขอบเผื่อรอบกรอบแสดงผล: `OUTER_MARGIN_RATIO` (เริ่ม 0.006)
  - กรอบกินขอบมากไป ให้ลดเป็น 0.004–0.005
- คุมสเกลเทียบกรอบคร่าว: `MAX_SCALE_OVER_COARSE`/`MIN_SCALE_OVER_COARSE` (เริ่ม 1.06/0.92)
  - ฟอร์มเพี้ยนจากการถ่าย คลายเป็น 1.08/0.90; ถ้าบาน/หดผิด ลดเป็น 1.04/0.96
- หาเส้นกรอบด้วยโปรเจกชันแกน X/Y: `thr_x = max(6, rH*k)`, `thr_y = max(6, rW*k)` (k เริ่ม 0.10)
  - ภาพซีดใช้ 0.12; ภาพคม/มีเงาเยอะ 0.12–0.14; ภาพสะอาด 0.08–0.10
- หน้าต่างวัดต่อช่อง (ครึ่งกว้าง/สูง): factor = `0.28` ของขนาดช่อง
  - วงกลมใหญ่/เหลื่อม เพิ่มเป็น 0.30–0.33; โดนกรอบรบกวน ลดเป็น 0.24–0.26
- หน้ากากวงแหวน `_ring_mask`: `r_in = 0.30*0.5`, `r_out = 0.86*0.5` ของด้านสั้น
  - ฝนชิดขอบ เพิ่ม `r_out` 0.88–0.92; เส้นกรอบรบกวน ลดเป็น 0.80–0.84
- เกณฑ์ “ถูกฝน”: `MIN_FILL_RATIO = 0.40` และต้องชนะอันดับ 2 `> 0.12`
  - ฝนบาง ลดเป็น 0.32–0.38; ถ้าสองวงเข้มใกล้กัน เพิ่ม diff เป็น 0.15–0.18
- กันพาเนลบน drift: `LIMITED_SHIFT_X/Y = 0.10`, `LIMITED_SCALE = 0.08`
  - ดริฟต์บ่อย ลด shift เป็น 0.06–0.08; ถ้า warp เพี้ยน คลาย scale เป็น 0.10–0.12
- จูนรายพาเนล: `PANEL_BIAS[(dx,dy,dw,dh)]` (เป็นสัดส่วนของ W/H)
  - คลาดทิศคงที่ ปรับทีละ 0.005–0.010 แล้วตรวจผล

## สูตรจูนเร็ว (สถานการณ์จริง)
- ภาพซีด/เบลอ: k โปรเจกชัน ~0.12, `MIN_FILL_RATIO` ~0.36, diff ~0.15, factor หน้าต่าง 0.30, `r_out` ~0.84, scale limit 1.08/0.90
- วงกลมใหญ่/เหลื่อม: factor 0.30–0.33, `r_out` 0.88–0.92
- โดนเส้นกรอบกวน: factor 0.24–0.26, `OUTER_MARGIN_RATIO` 0.004–0.005
- พาเนลบนเลื่อนไปมา: `LIMITED_SHIFT_X/Y` 0.06–0.08, `LIMITED_SCALE` 0.10–0.12

## ค่าตั้งต้นปัจจุบัน (จากโค้ด)
- ขนาด warp: `backend/typhoon-grader/app.py:20` → `TARGET_W/H = 1200/1700`
- ขยาย ROI/ขอบเผื่อ: `backend/typhoon-grader/app.py:35` → `REFINE_PAD_RATIO=0.018`, `backend/typhoon-grader/app.py:37` → `OUTER_MARGIN_RATIO=0.006`
- คุมสเกลเทียบ coarse: `backend/typhoon-grader/app.py:39` → `MAX=1.06`, `backend/typhoon-grader/app.py:40` → `MIN=0.92`
- โปรเจกชัน X/Y: `backend/typhoon-grader/app.py:253`, `backend/typhoon-grader/app.py:254` (k=0.10)
- หน้าต่างต่อช่อง: `backend/typhoon-grader/app.py:359`, `backend/typhoon-grader/app.py:361`, `backend/typhoon-grader/app.py:434`, `backend/typhoon-grader/app.py:436` (factor=0.28)
- หน้ากากวงแหวน: `backend/typhoon-grader/app.py:318` (`r_in=0.30*0.5`, `r_out=0.86*0.5`)
- เกณฑ์ฝน: `backend/typhoon-grader/app.py:364` → `MIN_FILL_RATIO=0.40`, diff `>0.12` ที่ `backend/typhoon-grader/app.py:401` (ID ดู `:439`, `:486`)
- กัน drift พาเนลบน: `backend/typhoon-grader/app.py:532` → `LIMITED_SHIFT_X/Y=0.10`, `LIMITED_SCALE=0.08`
- จูนรายพาเนล: `backend/typhoon-grader/app.py:54` → `PANEL_BIAS`

## คำสั่งที่ใช้บ่อย (รัน/ทดสอบเร็ว)
- รัน Backend (FastAPI):
  - จากโฟลเดอร์รากโปรเจกต์
    - `uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload`

- รัน Flutter และชี้ API แบบกำหนดเอง:
  - ภายใต้ `exam/`
    - `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`

- ทดสอบอัปโหลด OMR ไปยัง API โดยตรง (curl):
  - Windows (PowerShell/WSL ที่มี curl)
    - `curl -X POST "http://127.0.0.1:8000/omr/grade" -F "quizId=123" -F "term=1" -F "year=2025" -F "grader=teacherA" -F "file=@D:/path/to/omr.jpg;type=image/jpeg"`

หมายเหตุ: ฟิลด์ที่จำเป็นของ `/omr/grade` คือ `quizId`, `term`, `year` และ `file`

## ตัวอย่างโค้ด (เชื่อมค่าจากไฟล์โปรไฟล์ JSON)
กรณีต้องการเปลี่ยนพารามิเตอร์จากไฟล์ `docs/โปรไฟล์แนะนำการจูน_OMR.json` ให้รองรับโหลดเข้ากับตัวอ่าน คุณสามารถปรับเพิ่มตัวแปรและตัวโหลดใน `backend/typhoon-grader/app.py` แบบนี้ (แนวทาง):

```python
# app.py (ส่วนบนสุด ใกล้ CONFIG)
RING_INNER_FACTOR_BASE = 0.30
RING_OUTER_FACTOR_BASE = 0.86
PROJECTION_K = 0.10
MIN_DIFF_RATIO = 0.12

def load_calibration_profile(path: str | Path, profile_name: str = "recommended_bestfit"):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        prof = data["profiles"].get(profile_name) or data["profiles"].get("current_from_code")
        if not prof:
            return
        g = globals()
        for k_map, k_json in [
            ("TARGET_W", "target_w"), ("TARGET_H", "target_h"),
            ("REFINE_PAD_RATIO", "refine_pad_ratio"), ("OUTER_MARGIN_RATIO", "outer_margin_ratio"),
            ("MAX_SCALE_OVER_COARSE", "max_scale_over_coarse"), ("MIN_SCALE_OVER_COARSE", "min_scale_over_coarse"),
            ("PROJECTION_K", "projection_k"), ("RING_INNER_FACTOR_BASE", "ring_inner_factor_base"),
            ("RING_OUTER_FACTOR_BASE", "ring_outer_factor_base"), ("LIMITED_SHIFT_X", "limited_shift_x"),
            ("LIMITED_SHIFT_Y", "limited_shift_y"), ("LIMITED_SCALE", "limited_scale"),
        ]:
            if k_json in prof: g[k_map] = prof[k_json]
        if "min_fill_ratio" in prof: g["MIN_FILL_RATIO_GLOBAL"] = prof["min_fill_ratio"]
        if "min_diff_ratio" in prof: g["MIN_DIFF_RATIO"] = prof["min_diff_ratio"]
    except Exception:
        pass

# แทนค่าคงที่ในโค้ดเดิมให้ใช้ตัวแปรด้านบน
def _ring_mask(h: int, w: int) -> np.ndarray:
    cy, cx = h // 2, w // 2
    y, x = np.ogrid[:h, :w]
    rr = np.sqrt((y - cy) ** 2 + (x - cx) ** 2)
    r_in = min(h, w) * float(RING_INNER_FACTOR_BASE) * 0.5
    r_out = min(h, w) * float(RING_OUTER_FACTOR_BASE) * 0.5
    return (((rr >= r_in) & (rr <= r_out)).astype(np.uint8)) * 255

# ภายในส่วน refine ที่หา threshold โปรเจกชัน
# เดิม: thr_x = max(6, rH * 0.10) → แก้เป็น
thr_x = max(6, rH * float(PROJECTION_K))
thr_y = max(6, rW * float(PROJECTION_K))

# ภายในตัวอ่านช่องคำตอบ/ID ให้ใช้เกณฑ์จากตัวแปรกลาง
MIN_FILL_RATIO = globals().get("MIN_FILL_RATIO_GLOBAL", 0.40)
```

ตัวอย่างเรียกโหลดก่อนเริ่มงาน (เช่น ในจุดที่ FastAPI import `app.py` มาใช้):
```python
# เรียกครั้งเดียวพอ (ไฟล์อยู่ในรากโปรเจกต์)
load_calibration_profile("docs/โปรไฟล์แนะนำการจูน_OMR.json", profile_name="recommended_bestfit")
```
