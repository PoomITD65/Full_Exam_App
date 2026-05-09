# API อ้างอิงแบบย่อ (ใช้งานโดยแอป)
สรุปเส้นทางที่ถูกเรียกจากแอป Flutter ใน `exam/lib/app/services/api_service.dart`
## Auth
- `POST /auth/login` ล็อกอิน
- `GET /auth/me` ข้อมูลผู้ใช้จาก JWT
## Exams
- `GET /exams/summary` สรุปชุดข้อสอบของฉัน
- `GET /exams/mine?limit=N` รายการข้อสอบของฉัน
- `POST /exams` สร้าง/อัปเดตชุดข้อสอบ
- `GET /exams/daily_summary?start=YYYY-MM-DD&end=YYYY-MM-DD` จำนวนอัปเดตรายวัน
- `GET /exams/daily_breakdown?day=YYYY-MM-DD` รายวันแยกชุด
- `GET /exams/result?quizId&stdNo&includeImage=1` ผลรายคน
- `GET /exams/choices?quizId` ดึงข้อ-เฉลย-สถานะใช้
- `PUT /exams/choice/{quizId}/{no}` อัปเดตเฉลย/คะแนน/สถานะใช้
## OMR
- `POST /omr/grade` อัปโหลดรูป OMR เพื่ออ่านและบันทึกผล
หมายเหตุ: โครงสร้างผลตอบกลับอาจอิงสคีมาปัจจุบันใน `backend/api/routers/*.py` และอาจเปลี่ยนได้ตามฐานข้อมูลจริง
