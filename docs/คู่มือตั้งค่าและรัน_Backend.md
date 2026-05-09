# ตั้งค่าและรัน Backend (FastAPI)
## เตรียมสภาพแวดล้อม
- ติดตั้ง Python 3.11 และ `pip`
- สร้าง virtualenv และติดตั้ง `backend/requirements.txt`
## การรันด้วย Uvicorn (จากโฟลเดอร์รากโปรเจกต์)
- คำสั่งตัวอย่าง: `uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload`
- อนุญาต CORS ชั่วคราว ถูกตั้งแบบเปิดใน `backend/main.py` ปรับ `allow_origins` เมื่อขึ้นโปรดักชัน
## การอ้างอิงไฟล์สำคัญ
- จุดเริ่มระบบ: `backend/main.py`
- เราเตอร์หลัก: `backend/api/routers/*.py`
- ตัวอ่าน OMR: `backend/typhoon-grader/app.py`
## ตั้งค่าเชื่อมต่อฐานข้อมูล
- ดูที่ `backend/core/db.py` และ `.env`
- ตารางเป้าหมายหลัก: `tblAcdQuiz`, `tblAcdQuizResult`, `tblAcdQuizChoice`, ฯลฯ
## ชี้แอปหน้า Flutter ให้ถูกเซิร์ฟเวอร์
- ดู `exam/lib/app/services/api_service.dart` ฟังก์ชัน `baseUrl` รองรับ `API_BASE_URL` ผ่าน `--dart-define`
