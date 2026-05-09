# คู่มือการปรับแกน X,Y สำหรับการแก้ไขการตรวจจับฝน/อ่านวงกลม (ฉบับเต็ม)

เอกสารฉบับเต็มนี้สรุปแนวคิดและขั้นตอนการจูนแกน X,Y และพารามิเตอร์ที่เกี่ยวข้องกับการอ่านวงกลม (OMR) ให้ได้ผลลัพธ์ที่นิ่งและเชื่อถือได้ อ้างอิงโค้ดจริงใน `backend/typhoon-grader/app.py` พร้อมตัวอย่างตัวเลขและโค้ดตัวอย่างสำหรับนำไปใช้ต่อยอด

## 1) ภาพรวมและคำจำกัดความ
- แกน X: พิกเซลแนวนอนใน ROI หลัง warp
- แกน Y: พิกเซลแนวตั้งใน ROI หลัง warp
- กระบวนการหลัก: warp → กำหนดกรอบคร่าว → refine หา “กรอบจริง” ด้วยกริด/โปรเจกชัน X,Y → อ่านเซลล์ด้วยหน้าต่างวัด + หน้ากากวงแหวน → ตัดสินคำตอบด้วยเกณฑ์ความเข้มและส่วนต่างคะแนน

## 2) พารามิเตอร์สำคัญจาก app.py (ใช้งานจริง)
- ขนาดภาพหลัง warp: `TARGET_W/H = 1200/1700`
- ขยายกรอบหาเส้นจริง: `REFINE_PAD_RATIO = 0.018`
- ขอบเผื่อแสดงผล: `OUTER_MARGIN_RATIO = 0.006`
- จำกัดสเกลเทียบ coarse: `MAX/MIN_SCALE_OVER_COARSE = 1.06/0.92`
- อัตราส่วนกว้าง/สูงกรอบ (คำตอบ): `AR_MIN/MAX = 0.50/0.82`; (ID): `ID_AR_MIN/MAX = 0.60/0.90`
- ความทึบ (solidity) และความแน่นพื้นที่: `MIN_SOLIDITY = 0.85`, `MIN_RECT_FILL = 0.52`
- พาเนลบนที่เข้มงวด: `TOP_PANELS = {id,q1_10,q11_20}` พร้อม `TOP_PAD_EXTRA = (10,8)`
- โปรเจกชันหาเส้นกรอบ: `thr_x = max(6, rH*0.10)`, `thr_y = max(6, rW*0.10)`
- หน้าต่างวัดต่อช่อง: factor ครึ่งขนาด `0.28` ของขนาดช่องทั้งแกน X,Y
- หน้ากากวงแหวน `_ring_mask`: `r_in = 0.30*0.5`, `r_out = 0.86*0.5` ของด้านสั้นของเซลล์
- เกณฑ์ “ถูกฝน”: `MIN_FILL_RATIO = 0.40` และต้องชนะอันดับ 2 อย่างน้อย `0.12`
- จำกัดพาเนลบนไม่ให้ drift: `LIMITED_SHIFT_X/Y = 0.10`, `LIMITED_SCALE = 0.08`
- จูนรายพาเนล: `PANEL_BIAS[(dx,dy,dw,dh)]` เป็นสัดส่วนของ `W/H`

## 3) ตัวอย่างแกนและตัวเลขคำนวณ (เข้าใจภาพรวม)
### A) พาเนลคำตอบ (Answers Grid)
- กำหนด: `n_choices = 5`, `n_questions = 10`
- สมมติครอปภายใน (หลัง `_inner_crop_for_panel`) ได้ `rw = 600`, `rh = 400`, ออฟเซ็ต `(rx, ry)`
- ศูนย์กลางต่อคอลัมน์: `centers_x[i] = int((i+0.5)*rw/n_choices)` → ประมาณ `[60,180,300,420,540]`
- ศูนย์กลางต่อแถว: `centers_y[j] = int((j+0.5)*rh/n_questions)` → ประมาณ `[20,60,100,140,180,220,260,300,340,380]`
- ครึ่งกว้าง/สูงของหน้าต่างวัด: `hx = int((rw/n_choices)*0.28) ≈ 34`, `hy = int((rh/n_questions)*0.28) ≈ 11`
- ตัวอย่างพิกัดเซลล์ C=2,Q=3: X=[rx+266, rx+334], Y=[ry+129, ry+151]

ผลกระทบการจูน factor 0.28:
- เพิ่มเป็น 0.30–0.33: หน้าต่างใหญ่ขึ้น เก็บสัญญาณ “ชิดขอบ” ดีขึ้น แต่เสี่ยงโดนเส้นกรอบรบกวน
- ลดเป็น 0.24–0.26: เน้นกลาง ลดโดนกรอบ แต่ถ้าฝนชิดขอบอาจอ่านน้อยลง

### B) พาเนลรหัสนักเรียน (Student ID)
- กำหนด: `n_cols = 6`, `n_rows = 10`; สมมติ `rw = 520`, `rh = 420`
- ศูนย์กลาง X ต่อหลัก: ประมาณ `[43,130,217,303,390,477]`
- ศูนย์กลาง Y ต่อเลข 0–9: ประมาณ `[21,63,105,147,189,231,273,315,357,399]`
- ครึ่งกว้าง/สูง: `hx ≈ 24`, `hy ≈ 12`

### C) โปรเจกชันหาเส้นกรอบจริง
- สมมติ `rW = 450`, `rH = 300` → `thr_x = max(6, 30) = 30`, `thr_y = max(6, 45) = 45`

### D) หน้ากากวงแหวนของเซลล์
- ด้านสั้นของเซลล์ ~ 2*hy ≈ 22 → `r_in ≈ 22*0.30*0.5 ≈ 3.3`, `r_out ≈ 22*0.86*0.5 ≈ 9.46`
- จูน: วงกลมพิมพ์หนา/ต้องการเก็บชานนอก → `r_out 0.88–0.92`; มีเส้นกรอบรบกวน → `r_out 0.80–0.84`

## 4) สูตรและแนวทางจูนแบบเร็ว (ตามสถานการณ์)
- ภาพซีด/เบลอ/แสงไม่สม่ำเสมอ:
  - โปรเจกชัน: k ~ 0.12
  - เกณฑ์ฝน: `MIN_FILL_RATIO ~ 0.36`, diff ~ 0.15
  - หน้าต่างวัด: factor 0.30, ring `r_out ~ 0.84`
  - สัดส่วนเพี้ยน: `MAX/MIN_SCALE_OVER_COARSE` → 1.08/0.90
- วงกลมใหญ่/เหลื่อม:
  - factor 0.30–0.33, `r_out 0.88–0.92`
- โดนเส้นกรอบกวน:
  - factor 0.24–0.26, ลด `OUTER_MARGIN_RATIO` เป็น 0.004–0.005
- พาเนลบน drift:
  - `LIMITED_SHIFT_X/Y` 0.06–0.08, `LIMITED_SCALE` 0.10–0.12
- จูนรายพาเนล (offset/size ตายตัว):
  - ปรับ `PANEL_BIAS` ทีละ 0.005–0.010 ตามทิศที่คลาด แล้วทดสอบ

## 4.1) คำสั่งทดสอบเร็ว (Backend/Frontend/curl)
- รัน Backend (FastAPI):
  - `uvicorn main:app --host 0.0.0.0 --port 8000 --reload`
- รัน Flutter และกำหนด API URL:
  - ภายใต้ `exam/` → `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`
- ยิงทดสอบอัปโหลด OMR ด้วย curl:
  - `curl -X POST "http://127.0.0.1:8000/omr/grade" -F "quizId=123" -F "term=1" -F "year=2025" -F "grader=teacherA" -F "file=@D:/path/to/omr.jpg;type=image/jpeg"`

## 5) โค้ดตัวอย่าง (แนวคิด)
### Python: คำนวณ normalize และ threshold เบื้องต้นจากสถิติ
```python
import numpy as np

# y_raw: numpy array ของค่าสัญญาณ/สัดส่วนการฝนจากเซลล์
Ymin, Ymax = np.percentile(y_raw, 5), np.percentile(y_raw, 95)
a = 1.0 / max(1e-6, (Ymax - Ymin))
b = -Ymin * a

y_cal = a * y_raw + b
# ถ้าทิศกลับด้าน (ยิ่งฝนมากค่ายิ่งลด) ให้ invert
if invert_needed:
    y_cal = 1.0 - y_cal

# smoothing แบบ moving average
k = 7
kernel = np.ones(k) / k
y_smooth = np.convolve(y_cal, kernel, mode='same')

# threshold แบบง่ายจากค่ากลางสองกลุ่ม
thr = 0.5 * (np.median(y_smooth[no_rain_mask]) + np.median(y_smooth[rain_mask]))
```

### Dart: โครง RainCalibration + ฮิสเทอรีซิส/ดีบาวน์
```dart
class RainCalibration {
  final double a; // scale
  final double b; // offset
  final bool invert;
  RainCalibration({required this.a, required this.b, this.invert = false});
  double apply(double yRaw) {
    double y = a * yRaw + b;
    if (invert) y = 1.0 - y;
    return y.clamp(0.0, 1.0);
  }
}

class RainDetector {
  final RainCalibration cal;
  final double onThr;
  final double offThr;
  final int debounceN;
  bool isRaining = false;
  int _count = 0;
  RainDetector(this.cal, {this.onThr = 0.55, this.offThr = 0.45, this.debounceN = 3});
  bool update(double yRaw) {
    final y = cal.apply(yRaw);
    final trig = isRaining ? (y <= offThr) : (y >= onThr);
    if (trig) {
      if (++_count >= debounceN) { isRaining = !isRaining; _count = 0; }
    } else { _count = 0; }
    return isRaining;
  }
}
```

### Python: ผูกโปรไฟล์ JSON เข้ากับตัวอ่าน (ตัวอย่างปรับใน app.py)
```python
# เพิ่มตัวแปรและฟังก์ชันโหลด (ดูตัวอย่าง mapping ในเอกสารฉบับสั้น)
RING_INNER_FACTOR_BASE = 0.30
RING_OUTER_FACTOR_BASE = 0.86
PROJECTION_K = 0.10
MIN_DIFF_RATIO = 0.12

def load_calibration_profile(path: str | Path, profile_name: str = "recommended_bestfit"):
    # อ่านไฟล์ docs/โปรไฟล์แนะนำการจูน_OMR.json แล้ว map เข้า globals()
    ...

# ใช้ใน _ring_mask
def _ring_mask(h: int, w: int) -> np.ndarray:
    cy, cx = h // 2, w // 2
    y, x = np.ogrid[:h, :w]
    rr = np.sqrt((y - cy) ** 2 + (x - cx) ** 2)
    r_in = min(h, w) * float(RING_INNER_FACTOR_BASE) * 0.5
    r_out = min(h, w) * float(RING_OUTER_FACTOR_BASE) * 0.5
    return (((rr >= r_in) & (rr <= r_out)).astype(np.uint8)) * 255

# ใช้ในส่วน projection threshold
thr_x = max(6, rH * float(PROJECTION_K))
thr_y = max(6, rW * float(PROJECTION_K))

# ใช้เกณฑ์กลางสำหรับการตัดสิน
MIN_FILL_RATIO = globals().get("MIN_FILL_RATIO_GLOBAL", 0.40)

# เรียกตอน start-up
load_calibration_profile("docs/โปรไฟล์แนะนำการจูน_OMR.json")
```

## 6) เช็คลิสต์หลังจูน
- อ่านได้เสถียรบนชุดภาพหลากหลายสภาพแสง/การสแกน
- ค่าปุ่มจูนอยู่ในกรอบแนะนำ (ไม่สุดโต่งโดยไม่จำเป็น)
- คะแนนช่องที่ถูกฝนชนะอันดับ 2 อย่างชัดเจนตาม diff ที่ตั้งไว้
- พาเนลไม่ drift เกินกรอบ coarse และ bias รายพาเนลถูกต้อง

---
หมายเหตุ: ค่าตัวเลขที่ยกมาคือแนวทางเริ่มต้น แนะนำปรับ-ทดสอบกับชุดข้อมูลจริงเสมอ และเก็บค่าคอนฟิกเป็นไฟล์ภายนอกเพื่อจูนภาคสนามได้รวดเร็ว

มีคำถามหรือข้อสงสัยติดต่อ FB:Taku Maka ก่อนปี 69