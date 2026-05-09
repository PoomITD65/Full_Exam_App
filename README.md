# Full Exam App

เอกสารติดตั้งแบบละเอียด: `docs/คู่มือติดตั้งระบบ.md`

### Backend (FastAPI)
- `uvicorn main:app --host 0.0.0.0 --port 8000 --reload`

### Frontend (Flutter)
- ใน `exam/`: `flutter pub get`
- รันและชี้ API: `flutter run`

Note: Run Uvicorn from the project root so imports like `backend.api...` work. For more, see `docs/คู่มือตั้งค่าและรัน_Backend.md`.

