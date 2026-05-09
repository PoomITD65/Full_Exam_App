from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routers.system import router as system_router
from api.routers.auth import router as auth_router
from api.routers.exams import router as exams_router
from api.routers.profile import router as profile_router
from api.routers.omr import router as omr_router

app = FastAPI(title="Misschoo Demo API (Modular)")

# CORS — ปรับ allow_origins ในโปรดักชัน
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# รวมเส้นทาง
app.include_router(system_router)
app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(exams_router, prefix="/exams", tags=["exams"])
app.include_router(profile_router, prefix="/profile", tags=["profile"])
app.include_router(omr_router, prefix="/omr", tags=["omr"])
