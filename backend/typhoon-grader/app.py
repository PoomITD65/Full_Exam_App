import os, uuid, time, json
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional

import cv2
import numpy as np
from flask import Flask, request, jsonify, render_template, send_from_directory
from werkzeug.utils import secure_filename

# ================== CONFIG ==================
ROOT = Path(__file__).parent.resolve()
UPLOADS = ROOT / "uploads"
REPORTS = ROOT / "reports"
TEMPLATES = ROOT / "templates"
ANSWER_KEY_FILE = ROOT / "answer_key.json"

UPLOADS.mkdir(exist_ok=True)
REPORTS.mkdir(exist_ok=True)

# ขนาดเป้าหมายหลัง warp ให้คงสัดส่วนทุกใบ
TARGET_W, TARGET_H = 1200, 1700

# จำนวนตัวเลือกต่อข้อ
CHOICES = 5
TOTAL_QUESTIONS = 80
QUESTION_BLOCK_SIZE = 20
STUDENT_ID_COLS = 5
MIN_SHEET_ANSWER_COUNT = 12

# คีย์เฉลย
# ANSWER_KEY_FILE = ROOT / "answer_key.json"

# วาดวงกลม debug
CIRCLE_R = 11
CIRCLE_THICK = 2

# ปุ่มปรับกรอบ (refine)
REFINE_ENABLED = True
# ขยายกรอบค้นหาเล็กน้อยรอบ coarse (เพื่อหาเส้นจริง)
REFINE_PAD_RATIO = 0.018  # 1.8%
# ขอบเผื่อรอบกรอบผลลัพธ์ (เวลาวาดแสดง)
OUTER_MARGIN_RATIO = 0.006
# จำกัดสเกลสัมพัทธ์เทียบ coarse ไม่ให้บาน/เล็กเกินไป
MAX_SCALE_OVER_COARSE = 1.06
MIN_SCALE_OVER_COARSE = 0.92
# อัตราส่วนกว้าง/สูงคร่าว ๆ ของกล่องคำตอบ (ใช้กรอง contour)
AR_MIN, AR_MAX = 0.50, 0.82
ID_AR_MIN, ID_AR_MAX = 0.60, 0.90
# ความทึบและการเติมพื้นที่ของกรอบ (คัดกรอง noise)
MIN_SOLIDITY = 0.85
MIN_RECT_FILL = 0.52

# พาเนลด้านบนให้เข้มงวด/ขยายพิเศษ
TOP_PANELS = {"id"}
TOP_PAD_EXTRA = (10, 8)  # ลด padding เพื่อกัน drift ลงล่าง

# ====== PANEL BIAS (dx, dy, dw, dh เป็นสัดส่วนของ W/H) ======
# ใช้ปรับละเอียดต่อกล่องหลัง refine เพื่อตรงช่องจริงแบบพอดี
PANEL_BIAS = {
    "id": (0.000, 0.000, 0.000, 0.000),
}


app = Flask(__name__, template_folder=str(TEMPLATES), static_folder="static")


# ================== ANSWER KEY ==================
def load_answer_key() -> Tuple[Dict[str, str], int]:
    key: Dict[str, str] = {}
    spq = 1
    if ANSWER_KEY_FILE.exists(): # type: ignore
        try:
            data = json.loads(ANSWER_KEY_FILE.read_text(encoding="utf-8")) # type: ignore
            if isinstance(data, dict):
                raw_key = data.get("key") or {}
                if isinstance(raw_key, dict):
                    key = {str(k): str(v) for k, v in raw_key.items()}
                spq = int(data.get("score_per_question", 1))
        except Exception:
            key, spq = {}, 1
    return key, spq


# ================== MARKER / WARP ==================
def find_markers(img: np.ndarray) -> Optional[np.ndarray]:
    """
    พยายามหา marker 4 จุดมุม (สี่เหลี่ยม/วงดำ) แบบยืดหยุ่น
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (7, 7), 0)
    th = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
    th = cv2.morphologyEx(th, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)), 1)

    cnts, _ = cv2.findContours(th, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    H, W = th.shape
    area_img = H * W
    pts = []
    for c in cnts:
        area = cv2.contourArea(c)
        if not (0.0004 * area_img < area < 0.02 * area_img):
            continue
        x, y, w, h = cv2.boundingRect(c)
        ar = w / float(h + 1e-6)
        if 0.6 <= ar <= 1.6:
            hull = cv2.convexHull(c)
            solidity = area / (cv2.contourArea(hull) + 1e-6)
            if solidity >= 0.85:
                pts.append((x + w / 2.0, y + h / 2.0))

    if len(pts) < 4:
        return None

    pts = np.array(pts, dtype=np.float32)
    s = pts.sum(axis=1)
    d = np.diff(pts, axis=1).ravel()
    TL = pts[np.argmin(s)]
    BR = pts[np.argmax(s)]
    TR = pts[np.argmin(d)]
    BL = pts[np.argmax(d)]
    return np.array([TL, TR, BR, BL], dtype=np.float32)


def find_document_corners(img: np.ndarray) -> Optional[np.ndarray]:
    """
    Fallback for photographed sheets: detect the outer page border as a quadrilateral.
    This is more reliable than marker blobs when the paper is tilted or the markers
    are connected to the printed border.
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blur, 50, 150)
    edges = cv2.dilate(edges, cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5)), iterations=1)

    cnts, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    H, W = gray.shape
    min_area = W * H * 0.20
    candidates = []

    for c in cnts:
        area = cv2.contourArea(c)
        if area < min_area:
            continue

        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        if len(approx) != 4:
            continue

        pts = approx.reshape(4, 2).astype(np.float32)
        x, y, w, h = cv2.boundingRect(approx)
        ar = w / float(h + 1e-6)
        if not (0.45 <= ar <= 0.90):
            continue

        candidates.append((area, pts))

    if not candidates:
        return None

    pts = max(candidates, key=lambda item: item[0])[1]
    s = pts.sum(axis=1)
    d = np.diff(pts, axis=1).ravel()
    TL = pts[np.argmin(s)]
    BR = pts[np.argmax(s)]
    TR = pts[np.argmin(d)]
    BL = pts[np.argmax(d)]
    return np.array([TL, TR, BR, BL], dtype=np.float32)


def warp_to_standard(img: np.ndarray) -> np.ndarray:
    markers = find_document_corners(img)
    if markers is None:
        markers = find_markers(img)
    if markers is None:
        return cv2.resize(img, (TARGET_W, TARGET_H))
    dst = np.array(
        [[0, 0], [TARGET_W - 1, 0], [TARGET_W - 1, TARGET_H - 1], [0, TARGET_H - 1]], dtype=np.float32
    )
    M = cv2.getPerspectiveTransform(markers, dst)
    return cv2.warpPerspective(img, M, (TARGET_W, TARGET_H))


# ================== COARSE LAYOUT ==================
def layout_top_panels(H, W):
    # Template ปัจจุบันมีตารางเลขประจำตัว 5 หลักอยู่ขวาบน
    return [
        ("id", (int(0.774 * W), int(0.038 * H), int(0.186 * W), int(0.365 * H))),
    ]


def layout_bottom_panels(H, W):
    # Template ปัจจุบันมีคำตอบ 80 ข้อ แบ่ง 4 คอลัมน์ คอลัมน์ละ 20 ข้อ
    top = int(0.422 * H)
    height = int(0.535 * H)
    columns = [
        ("q1_20", (0.090, 0.180)),
        ("q21_40", (0.315, 0.180)),
        ("q41_60", (0.552, 0.195)),
        ("q61_80", (0.790, 0.185)),
    ]
    return [
        (name, (int(xr * W), top, int(wr * W), height))
        for name, (xr, wr) in columns
    ]


def layout_panels_from_markers(warped: np.ndarray) -> List[Tuple[str, Tuple[int, int, int, int]]]:
    H, W = warped.shape[:2]
    panels = layout_top_panels(H, W) + layout_bottom_panels(H, W)
    # ป้องกันล้นภาพ
    safe_panels: List[Tuple[str, Tuple[int, int, int, int]]] = []
    for nm, (x, y, w, h) in panels:
        if x + w > W: w = W - x
        if y + h > H: h = H - y
        safe_panels.append((nm, (x, y, w, h)))
    return safe_panels


# ================== REFINE LAYOUT BY REAL GRID EDGES ==================
def _clamp(v, lo, hi): return max(lo, min(v, hi))


def _limit_scale(coarse_w, coarse_h, w, h):
    max_w = int(coarse_w * MAX_SCALE_OVER_COARSE)
    max_h = int(coarse_h * MAX_SCALE_OVER_COARSE)
    min_w = int(coarse_w * MIN_SCALE_OVER_COARSE)
    min_h = int(coarse_h * MIN_SCALE_OVER_COARSE)
    return _clamp(w, min_w, max_w), _clamp(h, min_h, max_h)


def _refine_panel_outer_box(img: np.ndarray, rect: Tuple[int, int, int, int], is_id: bool) -> Tuple[int, int, int, int]:
    """
    หาเส้นกรอบตารางจริงใน ROI
    """
    if not REFINE_ENABLED:
        return rect

    H, W = img.shape[:2]
    x, y, w, h = rect

    # ขยายกรอบค้นหาเล็กน้อย
    pad_x = max(4, int(w * REFINE_PAD_RATIO))
    pad_y = max(4, int(h * REFINE_PAD_RATIO))
    if is_id:
        pad_x += TOP_PAD_EXTRA[0]
        pad_y += TOP_PAD_EXTRA[1]

    sx = _clamp(x - pad_x, 0, W - 1)
    sy = _clamp(y - pad_y, 0, H - 1)
    ex = _clamp(x + w + pad_x, 1, W)
    ey = _clamp(y + h + pad_y, 1, H)

    roi = img[sy:ey, sx:ex]
    rH, rW = roi.shape[:2]

    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)

    # เสริมเส้นกริด
    th = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                               cv2.THRESH_BINARY_INV, 21, 5)
    v_ker = cv2.getStructuringElement(cv2.MORPH_RECT, (1, max(10, rH // 12)))
    h_ker = cv2.getStructuringElement(cv2.MORPH_RECT, (max(10, rW // 16), 1))
    vlines = cv2.morphologyEx(th, cv2.MORPH_OPEN, v_ker, iterations=1)
    hlines = cv2.morphologyEx(th, cv2.MORPH_OPEN, h_ker, iterations=1)
    grid = cv2.bitwise_or(vlines, hlines)
    grid = cv2.dilate(grid, cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)), iterations=1)

    # หา contour ใหญ่ที่เหมือนกรอบนอกของตาราง
    cnts, _ = cv2.findContours(grid, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    candidates = []
    for c in cnts:
        x1, y1, w1, h1 = cv2.boundingRect(c)
        if w1 < 40 or h1 < 40:
            continue
        ar = w1 / float(h1 + 1e-6)
        ar_ok = (ID_AR_MIN <= ar <= ID_AR_MAX) if is_id else (AR_MIN <= ar <= AR_MAX)
        if not ar_ok:
            continue
        area = cv2.contourArea(c)
        fill = area / float(w1 * h1 + 1e-6)
        if fill < MIN_RECT_FILL:
            continue
        hull = cv2.convexHull(c)
        solid = area / (cv2.contourArea(hull) + 1e-6)
        if solid < MIN_SOLIDITY:
            continue
        candidates.append((x1, y1, w1, h1))

    # ถ้าไม่มี contour ที่ดี → ใช้ projection
    if not candidates:
        edges = cv2.Canny(gray, 60, 160)
        edges = cv2.dilate(edges, cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)), iterations=1)
        col_sum = edges.sum(axis=0) / 255.0
        row_sum = edges.sum(axis=1) / 255.0
        thr_x = max(6, rH * 0.10)
        thr_y = max(6, rW * 0.10)
        xs = np.where(col_sum >= thr_x)[0]
        ys = np.where(row_sum >= thr_y)[0]
        if xs.size > 5 and ys.size > 5:
            x1, x2 = xs[0], xs[-1]
            y1, y2 = ys[0], ys[-1]
            padx = max(2, (x2 - x1) // 50)
            pady = max(2, (y2 - y1) // 50)
            x1 = max(0, x1 - padx)
            x2 = min(rW - 1, x2 + padx)
            y1 = max(0, y1 - pady)
            y2 = min(rH - 1, y2 + pady)
            candidates.append((x1, y1, x2 - x1 + 1, y2 - y1 + 1))

    if not candidates:
        return rect

    # เลือกผู้ชนะ: ใหญ่+อยู่กลาง ROI + AR ใกล้เป้า
    best = None
    best_score = -1e9
    area_roi = rW * rH
    target_ar = 0.72 if is_id else 0.65
    for (x1, y1, w1, h1) in candidates:
        ar = w1 / float(h1 + 1e-6)
        ar_pen = abs(ar - target_ar)
        cx, cy = x1 + w1 / 2.0, y1 + h1 / 2.0
        center_pen = (abs(cx - rW / 2.0) / rW + abs(cy - rH / 2.0) / rH)
        score = (w1 * h1) / area_roi - 0.55 * center_pen - 0.35 * ar_pen
        if score > best_score:
            best_score, best = score, (x1, y1, w1, h1)

    bx, by, bw, bh = best

    # จำกัด scale เทียบ coarse
    bw, bh = _limit_scale(w, h, bw, bh)

    # ขยายขอบโชว์นิดหน่อย
    mx = max(2, int(bw * OUTER_MARGIN_RATIO))
    my = max(2, int(bh * OUTER_MARGIN_RATIO))
    bx = _clamp(bx - mx, 0, rW - 1)
    by = _clamp(by - my, 0, rH - 1)
    bw = _clamp(bw + 2 * mx, 10, rW - bx)
    bh = _clamp(bh + 2 * my, 10, rH - by)

    # map กลับพิกัดภาพเต็ม
    fx, fy, fw, fh = sx + bx, sy + by, bw, bh

    # guard: ไม่ให้ล้นกรอบ coarse ขยายเล็กน้อย
    gx1, gy1 = x - pad_x, y - pad_y
    gx2, gy2 = x + w + pad_x, y + h + pad_y
    fx = _clamp(fx, gx1, gx2 - 1)
    fy = _clamp(fy, gy1, gy2 - 1)
    fw = _clamp(fw, 10, gx2 - fx)
    fh = _clamp(fh, 10, gy2 - fy)

    return (fx, fy, fw, fh)


# ================== BINARIZE & GRID READER ==================
def _binarize(gray: np.ndarray):
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    return cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]


def _ring_mask(h: int, w: int) -> np.ndarray:
    cy, cx = h // 2, w // 2
    y, x = np.ogrid[:h, :w]
    rr = np.sqrt((y - cy) ** 2 + (x - cx) ** 2)
    r_in = min(h, w) * 0.30 * 0.5
    r_out = min(h, w) * 0.86 * 0.5
    return (((rr >= r_in) & (rr <= r_out)).astype(np.uint8)) * 255


def _dark_score(th: np.ndarray, y1: int, y2: int, x1: int, x2: int) -> int:
    cell = th[y1:y2, x1:x2]
    if cell.size == 0:
        return 0
    mask = _ring_mask(cell.shape[0], cell.shape[1])
    return int(cv2.countNonZero(cv2.bitwise_and(cell, mask)))


def _inner_crop_for_panel(H: int, W: int, panel_name: str) -> Tuple[int, int, int, int]:
    # ครอปเข้าในเล็กน้อย เพื่อหลบเส้นกรอบ
    top, bot, left, right = 0.08, 0.06, 0.06, 0.06
    if panel_name in ("q1_10", "q11_20"):
        top, bot, left, right = 0.015, 0.015, 0.025, 0.025
    rx = int(left * W)
    ry = int(top * H)
    rw = max(1, int((1.0 - left - right) * W))
    rh = max(1, int((1.0 - top - bot) * H))
    return rx, ry, rw, rh

def detect_answers_grid(panel_img: np.ndarray, n_questions: int, n_choices: int, panel_name: str):
    gray = cv2.cvtColor(panel_img, cv2.COLOR_BGR2GRAY)
    th = _binarize(gray)
    H, W = th.shape
    rx, ry, rw, rh = _inner_crop_for_panel(H, W, panel_name)
    crop = th[ry:ry + rh, rx:rx + rw]
    if crop.size == 0:
        return ["N/A"] * n_questions, []

    centers_x = [int((i + 0.5) * rw / n_choices) for i in range(n_choices)]
    centers_y = [int((i + 0.5) * rh / n_questions) for i in range(n_questions)]

    def half_width_x(i: int) -> int:  
        return max(2, int((rw / n_choices) * 0.28))
    def half_height_y(j: int) -> int: 
        return max(2, int((rh / n_questions) * 0.28))

    answers, picks = [], []
    MIN_FILL_RATIO = 0.40  # ✅ ต้องมีการฝน ≥ 40% ของพื้นที่วงกลม

    for q_idx in range(n_questions):
        y_c = centers_y[q_idx]
        hy = half_height_y(q_idx)
        y1 = ry + max(0, y_c - hy)
        y2 = ry + min(rh, y_c + hy)

        scores, ratios = [], []
        for c_idx in range(n_choices):
            x_c = centers_x[c_idx]
            hx = half_width_x(c_idx)
            x1 = rx + max(0, x_c - hx)
            x2 = rx + min(rw, x_c + hx)

            cell = th[y1:y2, x1:x2]
            if cell.size == 0:
                scores.append(0)
                ratios.append(0)
                continue

            mask = _ring_mask(cell.shape[0], cell.shape[1])
            filled = cv2.countNonZero(cv2.bitwise_and(cell, mask))
            total = cv2.countNonZero(mask)
            ratio = filled / float(total + 1e-6)

            scores.append(filled)
            ratios.append(ratio)

        best_idx = int(np.argmax(scores))
        best_ratio = ratios[best_idx]

        # หาค่าอันดับ 2 เพื่อกัน noise
        sorted_ratios = sorted(ratios, reverse=True)
        second_best = sorted_ratios[1] if len(sorted_ratios) > 1 else 0

        # ✅ เงื่อนไขใหม่: ต้องชัดเจนกว่าอันดับ 2
        if best_ratio >= MIN_FILL_RATIO and (best_ratio - second_best) > 0.12:
            ans = "ABCDE"[best_idx]
            answers.append(ans)
            cx = rx + centers_x[best_idx]
            cy = ry + centers_y[q_idx]
            picks.append((q_idx, best_idx, cx, cy, ans))
        else:
            answers.append("N/A")

    return answers, picks
# ================ STUDENT ID READER (NEW) ================
def detect_student_id(panel_img: np.ndarray, n_cols: int = 6):
    """
    [REVISED] อ่านรหัสนักเรียนจากช่องวงกลมโดยใช้ Grid Scan และวัดความเข้ม
    - แบ่งพาเนลเป็น 10 แถว (0-9) และ n_cols คอลัมน์ (6 หลัก)
    - เลือกแถวที่มีความเข้มสูงสุดในแต่ละคอลัมน์
    คืนค่า: (id_str, picks)
    """
    gray = cv2.cvtColor(panel_img, cv2.COLOR_BGR2GRAY)
    th = _binarize(gray)
    H, W = th.shape
    n_rows = 10  # 0-9

    # ใช้การครอปภายในแบบเดียวกันกับ detect_answers_grid เพื่อให้ข้ามเส้นกรอบ
    rx, ry, rw, rh = _inner_crop_for_panel(H, W, "id")
    crop = th[ry:ry + rh, rx:rx + rw]
    if crop.size == 0:
        return "?" * n_cols, []

    centers_x = [int((i + 0.5) * rw / n_cols) for i in range(n_cols)]
    centers_y = [int((i + 0.5) * rh / n_rows) for i in range(n_rows)]

    def half_width_x(i: int) -> int:  
        return max(2, int((rw / n_cols) * 0.28))
    def half_height_y(j: int) -> int: 
        return max(2, int((rh / n_rows) * 0.28))

    digits, picks = [], []
    MIN_FILL_RATIO = 0.40  # ใช้เกณฑ์เดียวกับคำตอบ (อาจปรับได้)
    MIN_DIFF_RATIO = 0.12 # ใช้เกณฑ์เดียวกับคำตอบ (ต้องชัดเจนกว่าอันดับ 2)

    for col_idx in range(n_cols):
        scores, ratios = [], []
        
        # 1. วนแต่ละแถว (0 ถึง 9)
        for row_idx in range(n_rows):
            # หาพิกัดของช่องวงกลม
            y_c = centers_y[row_idx]
            hy = half_height_y(row_idx)
            y1 = ry + max(0, y_c - hy)
            y2 = ry + min(rh, y_c + hy)

            x_c = centers_x[col_idx]
            hx = half_width_x(col_idx)
            x1 = rx + max(0, x_c - hx)
            x2 = rx + min(rw, x_c + hx)

            # วัดความเข้ม/อัตราส่วนการฝน
            cell = th[y1:y2, x1:x2]
            if cell.size == 0:
                scores.append(0)
                ratios.append(0)
                continue

            mask = _ring_mask(cell.shape[0], cell.shape[1])
            filled = cv2.countNonZero(cv2.bitwise_and(cell, mask))
            total = cv2.countNonZero(mask)
            ratio = filled / float(total + 1e-6)

            scores.append(filled)
            ratios.append(ratio)
        
        if not scores: # กันกรณีที่หาพิกัดไม่ได้เลย
            digits.append("?")
            continue
            
        # 2. เลือกตัวเลขที่ถูกฝนในคอลัมน์นี้ (แถวที่มีคะแนนสูงสุด)
        best_row_idx = int(np.argmax(scores))
        best_ratio = ratios[best_row_idx]

        # หาค่าอันดับ 2 เพื่อกัน noise
        sorted_ratios = sorted(ratios, reverse=True)
        second_best = sorted_ratios[1] if len(sorted_ratios) > 1 else 0
        
        # ✅ เงื่อนไข: ต้องชัดเจน (เข้ม) และชัดเจนกว่าอันดับ 2
        if best_ratio >= MIN_FILL_RATIO and (best_ratio - second_best) > MIN_DIFF_RATIO:
            digit = str(best_row_idx)
            digits.append(digit)
            # พิกัดสำหรับวาด debug
            cx = rx + centers_x[col_idx]
            cy = ry + centers_y[best_row_idx]
            picks.append((col_idx, best_row_idx, cx, cy, digit))
        else:
            digits.append("?")

    return "".join(digits), picks


# ================== TEMPLATE 80Q OVERRIDES ==================
def _inner_crop_for_panel(H: int, W: int, panel_name: str) -> Tuple[int, int, int, int]:
    if panel_name == "id":
        top, bot, left, right = 0.190, 0.025, 0.055, 0.055
    elif panel_name.startswith("q"):
        top, bot, left, right = 0.000, 0.000, 0.000, 0.000
    else:
        top, bot, left, right = 0.08, 0.06, 0.06, 0.06

    rx = int(left * W)
    ry = int(top * H)
    rw = max(1, int((1.0 - left - right) * W))
    rh = max(1, int((1.0 - top - bot) * H))
    return rx, ry, rw, rh


def detect_answers_grid(panel_img: np.ndarray, n_questions: int, n_choices: int, panel_name: str):
    gray = cv2.cvtColor(panel_img, cv2.COLOR_BGR2GRAY)
    th = _binarize(gray)
    H, W = th.shape
    rx, ry, rw, rh = _inner_crop_for_panel(H, W, panel_name)
    crop = th[ry:ry + rh, rx:rx + rw]
    if crop.size == 0:
        return ["N/A"] * n_questions, []

    centers_x = [int((i + 0.5) * rw / n_choices) for i in range(n_choices)]
    centers_y = [int((i + 0.5) * rh / n_questions) for i in range(n_questions)]
    hx = max(2, int((rw / n_choices) * 0.30))
    hy = max(2, int((rh / n_questions) * 0.30))
    min_fill_ratio = 0.46
    min_diff_ratio = 0.12

    answers, picks = [], []
    row_candidates = []
    for q_idx, y_c in enumerate(centers_y):
        y1 = ry + max(0, y_c - hy)
        y2 = ry + min(rh, y_c + hy)
        scores, ratios = [], []

        for c_idx, x_c in enumerate(centers_x):
            x1 = rx + max(0, x_c - hx)
            x2 = rx + min(rw, x_c + hx)
            cell = th[y1:y2, x1:x2]
            if cell.size == 0:
                scores.append(0)
                ratios.append(0)
                continue

            mask = _ring_mask(cell.shape[0], cell.shape[1])
            filled = cv2.countNonZero(cv2.bitwise_and(cell, mask))
            total = cv2.countNonZero(mask)
            scores.append(filled)
            ratios.append(filled / float(total + 1e-6))

        best_idx = int(np.argmax(scores))
        best_ratio = ratios[best_idx]
        sorted_ratios = sorted(ratios, reverse=True)
        second_best = sorted_ratios[1] if len(sorted_ratios) > 1 else 0
        row_candidates.append((q_idx, best_idx, best_ratio, second_best))

        if best_ratio >= min_fill_ratio and (best_ratio - second_best) > min_diff_ratio:
            ans = "ABCDE"[best_idx]
            answers.append(ans)
            picks.append((q_idx, best_idx, rx + centers_x[best_idx], ry + centers_y[q_idx], ans))
        else:
            answers.append("N/A")

    confident_count = sum(1 for ans in answers if ans != "N/A")
    if confident_count >= 8:
        for q_idx, best_idx, best_ratio, second_best in row_candidates:
            if answers[q_idx] != "N/A":
                continue
            if best_ratio < 0.30:
                continue
            ans = "ABCDE"[best_idx]
            answers[q_idx] = ans
            picks.append((q_idx, best_idx, rx + centers_x[best_idx], ry + centers_y[q_idx], ans))

    return answers, picks


def detect_student_id(panel_img: np.ndarray, n_cols: int = STUDENT_ID_COLS):
    gray = cv2.cvtColor(panel_img, cv2.COLOR_BGR2GRAY)
    th = _binarize(gray)
    H, W = th.shape
    n_rows = 10
    rx, ry, rw, rh = _inner_crop_for_panel(H, W, "id")
    if th[ry:ry + rh, rx:rx + rw].size == 0:
        return "0" * n_cols, [], [{"column": i + 1, "reason": "empty-id-panel"} for i in range(n_cols)]

    centers_x = [int((i + 0.5) * rw / n_cols) for i in range(n_cols)]
    centers_y = [int((i + 0.5) * rh / n_rows) for i in range(n_rows)]
    hx = max(2, int((rw / n_cols) * 0.30))
    hy = max(2, int((rh / n_rows) * 0.30))
    min_fill_ratio = 0.55
    min_diff_ratio = 0.10

    digits, picks = [], []
    warnings = []
    fallback_candidates = []
    for col_idx, x_c in enumerate(centers_x):
        scores, ratios = [], []
        for row_idx, y_c in enumerate(centers_y):
            y1 = ry + max(0, y_c - hy)
            y2 = ry + min(rh, y_c + hy)
            x1 = rx + max(0, x_c - hx)
            x2 = rx + min(rw, x_c + hx)
            cell = th[y1:y2, x1:x2]
            if cell.size == 0:
                scores.append(0)
                ratios.append(0)
                continue

            mask = _ring_mask(cell.shape[0], cell.shape[1])
            filled = cv2.countNonZero(cv2.bitwise_and(cell, mask))
            total = cv2.countNonZero(mask)
            scores.append(filled)
            ratios.append(filled / float(total + 1e-6))

        best_row_idx = int(np.argmax(scores))
        best_ratio = ratios[best_row_idx]
        high_rows = [idx for idx, ratio in enumerate(ratios) if ratio >= 0.75]
        sorted_ratios = sorted(ratios, reverse=True)
        second_best = sorted_ratios[1] if len(sorted_ratios) > 1 else 0
        fallback_candidates.append((col_idx, best_row_idx, best_ratio, second_best))

        if len(high_rows) > 1:
            digit = str(best_row_idx)
            digits.append(digit)
            picks.append((col_idx, best_row_idx, rx + centers_x[col_idx], ry + centers_y[best_row_idx], digit))
            warnings.append({
                "column": col_idx + 1,
                "reason": "multiple-marks",
                "candidates": high_rows,
            })
        elif best_ratio >= min_fill_ratio and (best_ratio - second_best) > min_diff_ratio:
            digit = str(best_row_idx)
            digits.append(digit)
            picks.append((col_idx, best_row_idx, rx + centers_x[col_idx], ry + centers_y[best_row_idx], digit))
        else:
            digit = str(best_row_idx)
            digits.append(digit)
            warnings.append({
                "column": col_idx + 1,
                "reason": "ambiguous",
                "candidate": best_row_idx,
                "best_ratio": round(float(best_ratio), 3),
                "second_ratio": round(float(second_best), 3),
            })

    detected_count = sum(1 for digit in digits if digit != "?")
    if detected_count >= max(1, n_cols - 1):
        for col_idx, best_row_idx, best_ratio, second_best in fallback_candidates:
            if digits[col_idx] != "?":
                continue
            if best_ratio < 0.45:
                continue
            digit = str(best_row_idx)
            digits[col_idx] = digit
            picks.append((col_idx, best_row_idx, rx + centers_x[col_idx], ry + centers_y[best_row_idx], digit))

    student_id = "".join(digits)
    hard_invalid = any(
        w.get("reason") != "ambiguous" or float(w.get("best_ratio", 0)) < min_fill_ratio
        for w in warnings
    )
    if hard_invalid:
        student_id = ""
    return student_id, picks, warnings

# ================== HELPERS ==================
def _apply_panel_biases(refined: List[Tuple[str, Tuple[int, int, int, int]]], W: int, H: int):
    """
    ปรับตำแหน่ง/ขนาดกล่องแบบละเอียดเป็นสัดส่วนของภาพ
    """
    new_panels = []
    for nm, (x, y, w, h) in refined:
        if nm in PANEL_BIAS:
            dxr, dyr, dwr, dhr = PANEL_BIAS[nm]
            dx = int(round(dxr * W)); dy = int(round(dyr * H))
            dw = int(round(dwr * W)); dh = int(round(dhr * H))
            x = _clamp(x + dx, 0, W - 1)
            y = _clamp(y + dy, 0, H - 1)
            w = _clamp(w + dw, 10, W - x)
            h = _clamp(h + dh, 10, H - y)
        new_panels.append((nm, (x, y, w, h)))
    return new_panels


# ================== PIPELINE ==================
def omr_process(
    img: np.ndarray,
    key_override: Optional[Dict[str, str]] = None,
) -> Tuple[Dict[str, Any], np.ndarray]:
    warped = warp_to_standard(img)
    debug = warped.copy()
    H, W = warped.shape[:2]

    coarse = layout_panels_from_markers(warped)

    # refine เฉพาะตารางเลขประจำตัว เพราะ answer blocks ไม่มีกรอบนอกชัดเจน
    refined: List[Tuple[str, Tuple[int, int, int, int]]] = []
    for nm, rect in coarse:
        if nm == "id":
            refined.append((nm, _refine_panel_outer_box(warped, rect, is_id=True)))
        else:
            refined.append((nm, rect))

    # จำกัดการเลื่อน/ยืดหดของพาเนลบนเทียบ coarse (กัน drift ลงล่าง)
    coarse_map = {nm: r for nm, r in coarse}
    LIMITED_SHIFT_X, LIMITED_SHIFT_Y, LIMITED_SCALE = 0.10, 0.10, 0.08
    tmp = []
    for nm, (x, y, w, h) in refined:
        cx, cy, cw, ch = coarse_map[nm]
        if nm in TOP_PANELS:
            max_dx = int(cw * LIMITED_SHIFT_X); max_dy = int(ch * LIMITED_SHIFT_Y)
            min_w = int(cw * (1 - LIMITED_SCALE)); max_w = int(cw * (1 + LIMITED_SCALE))
            min_h = int(ch * (1 - LIMITED_SCALE)); max_h = int(ch * (1 + LIMITED_SCALE))
            x = _clamp(x, cx - max_dx, cx + max_dx)
            y = _clamp(y, cy - max_dy, cy + max_dy)
            w = _clamp(w, min_w, max_w)
            h = _clamp(h, min_h, max_h)
        tmp.append((nm, (x, y, w, h)))
    refined = tmp

    # ปรับด้วย PANEL_BIAS
    refined = _apply_panel_biases(refined, W, H)

    # วาดกรอบสีน้ำเงิน
    for i, (nm, (x, y, w, h)) in enumerate(refined, start=1):
        cv2.rectangle(debug, (x, y), (x + w, y + h), (255, 0, 0), 2)
        cv2.putText(debug, f"P{i}:{nm}", (x, max(0, y - 6)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)

    # อ่านคำตอบ + รหัสนักเรียน
    if key_override is not None:
        key = key_override
    else:
        key, _ = load_answer_key()

    active_questions = TOTAL_QUESTIONS
    keyed_numbers = []
    for q in key.keys():
        if isinstance(q, str) and q.startswith("Q") and q[1:].isdigit():
            keyed_numbers.append(int(q[1:]))
    if keyed_numbers:
        active_questions = max(1, min(TOTAL_QUESTIONS, max(keyed_numbers)))

    answers: Dict[str, str] = {}
    student_id = "?" * STUDENT_ID_COLS
    student_id_warnings: List[Dict[str, Any]] = []
    panel_order = ["q1_20", "q21_40", "q41_60", "q61_80"]

    for nm, (x, y, w, h) in refined:
        panel = warped[y:y + h, x:x + w]

        if nm == "id":
            # อ่านรหัสนักเรียน (10 หลัก)
            sid, id_picks, student_id_warnings = detect_student_id(panel, n_cols=STUDENT_ID_COLS)
            student_id = sid
            # วาดวงกลม id (สีฟ้า)
            for (col, row, cx, cy, dg) in id_picks:
                cv2.circle(debug, (x + cx, y + cy), CIRCLE_R, (255, 165, 0), CIRCLE_THICK)  # ส้มฟ้า
            continue

        base = panel_order.index(nm) * QUESTION_BLOCK_SIZE + 1
        if base > active_questions:
            continue

        arr, picks = detect_answers_grid(panel, QUESTION_BLOCK_SIZE, CHOICES, panel_name=nm)
        for q_idx, ans in enumerate(arr):
            if base + q_idx > active_questions:
                continue
            qi = f"Q{base + q_idx}"
            answers[qi] = ans
        # วาดวงกลมผล
        for (q_idx, c_idx, cx, cy, ans) in picks:
            qi = f"Q{base + q_idx}"
            if ans in "ABCDE":
                color = (0, 255, 0) if key.get(qi) == ans else (0, 0, 255)
            else:
                color = (180, 180, 180)
            cv2.circle(debug, (x + cx, y + cy), CIRCLE_R, color, CIRCLE_THICK)

    answers_sorted = {f"Q{i}": answers.get(f"Q{i}", "N/A") for i in range(1, active_questions + 1)}
    if sum(1 for ans in answers_sorted.values() if ans != "N/A") < MIN_SHEET_ANSWER_COUNT:
        answers_sorted = {q: "N/A" for q in answers_sorted}
    student_id_hard_invalid = any(
        warning.get("reason") != "ambiguous"
        or float(warning.get("best_ratio", 0)) < 0.55
        for warning in student_id_warnings
    )
    return {
        "student_id": student_id,
        "student_id_valid": not student_id_hard_invalid,
        "student_id_warnings": student_id_warnings,
        "answers": answers_sorted,
    }, debug


# ================== ROUTES ==================
@app.get("/")
def home():
    # ถ้าไม่มีหน้าเว็บ ก็ส่งข้อความง่าย ๆ
    if not (TEMPLATES / "index.html").exists():
        return "OMR Service is running. POST /grade with an image file."
    return render_template("index.html")


@app.post("/grade")
def grade():
    f = request.files.get("file")
    if not f or not f.filename:
        return jsonify({"error": "no-file"}), 400
    ext = Path(secure_filename(f.filename)).suffix.lower() or ".jpg"
    fname = f"{int(time.time())}_{uuid.uuid4().hex}{ext}"
    fpath = str(UPLOADS / fname)
    f.save(fpath)

    img = cv2.imread(fpath, cv2.IMREAD_COLOR)
    omr, dbg = omr_process(img)
    dbg_name = Path(fname).stem + "_debug" + ext
    cv2.imwrite(str(REPORTS / dbg_name), dbg)

    key, spq = load_answer_key()
    total_questions = 0
    if key:
        nums = [
            int(q[1:])
            for q in key.keys()
            if isinstance(q, str) and q.startswith("Q") and q[1:].isdigit()
        ]
        total_questions = max(nums) if nums else TOTAL_QUESTIONS
    total = total_questions * spq if key else None
    score = None
    correct_count = None
    answered_count = sum(
        1 for ans in (omr.get("answers", {}) or {}).values()
        if ans not in (None, "N/A")
    )
    per_question: List[Dict[str, Any]] = []
    if key:
        correct_count = 0
        answers = omr.get("answers", {}) or {}
        for i in range(1, total_questions + 1):
            q = f"Q{i}"
            selected = answers.get(q, "N/A")
            correct = key.get(q)
            is_correct = selected == correct
            if is_correct:
                correct_count += 1
            per_question.append({
                "q": i,
                "selected": selected,
                "correct": correct,
                "isCorrect": is_correct,
                "points": spq if is_correct else 0,
            })
        score = correct_count * spq
    return jsonify({
        "student_id": omr.get("student_id"),
        "student_id_valid": omr.get("student_id_valid", True),
        "student_id_warnings": omr.get("student_id_warnings", []),
        "answers": omr.get("answers"),
        "score": score,
        "total": total,
        "total_questions": total_questions,
        "answered_count": answered_count,
        "correct_count": correct_count,
        "points_per_question": spq if key else None,
        "per_question": per_question,
        "debug_image": f"/reports/{dbg_name}"
    })


@app.get("/set_answer_key")
def get_key_page():
    # ถ้าไม่มีหน้าเว็บ ก็ให้โพสต์ JSON แทน
    if not (TEMPLATES / "key_form.html").exists():
        return "POST /set_answer_key with JSON: {'key': {'Q1':'A',...}, 'score_per_question': 1}"
    return render_template("key_form.html")


@app.post("/set_answer_key")
def set_key():
    try:
        payload = request.get_json(force=True, silent=False)
        ANSWER_KEY_FILE.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        return jsonify({"status": "success", "message": "Saved"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400


@app.get("/reports/<path:filename>")
def reports_file(filename):
    return send_from_directory(str(REPORTS), filename)


# ================== MAIN ==================
if __name__ == "__main__":
    print("Running OMR App (refined blue boxes matched to real grid + student ID)")
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=True)
