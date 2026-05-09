# schemas/exams.py
from pydantic import BaseModel, Field
from typing import Optional

class CreateExamReq(BaseModel):
    title: str
    subjectNo: str
    term: str
    year: int
    total: int
    ppercent: Optional[float] = Field(None, ge=0, le=100)
    typSubject: Optional[str] = Field(None, description="เช่น 'Subject' (ถ้าไม่ส่งจะใช้ค่าเริ่มต้น)")
    quizKind: Optional[str] = Field(None, description="Pretest/Posttest/Midterm/Final/Other")
