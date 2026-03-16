from fastapi import FastAPI # type: ignore
from fastapi.middleware.cors import CORSMiddleware # type: ignore
from app.routers import auth, users, documents, stats, dates, translate, transactions
from pathlib import Path
from fastapi.staticfiles import StaticFiles # type: ignore
from app.database import engine, Base


app = FastAPI(
    title="Daaga API",
    description="Backend FastAPI pour le projet Daaga 🚀",
    version="1.0.0",
)

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ à restreindre en production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclure les routes
app.include_router(auth.router)       # /auth/...
app.include_router(users.router)      # /users/...
app.include_router(documents.router)  # /documents/... (si défini dans documents.py)
app.include_router(stats.router)      # /stats/...
app.include_router(dates.router)
app.include_router(translate.router)
app.include_router(transactions.router)


#UPLOAD_DIR = Path(__file__).parent / "uploads"   # 🔹 reste dans app/
#app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

@app.get("/")
async def read_root():
    return {"message": "Bienvenue sur FastAPI Daaga 🚀"}