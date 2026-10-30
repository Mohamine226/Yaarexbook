from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select

from app.config import ADMIN_EMAIL, ADMIN_PASSWORD, COVER_DIR
from app.database import SessionLocal, create_tables
from app.models import User
from app.routers import admin, auth, documents, users
from app.security import hash_password


async def seed_admin() -> None:
    """Crée le premier administrateur à partir de ADMIN_EMAIL / ADMIN_PASSWORD."""
    if not ADMIN_EMAIL or not ADMIN_PASSWORD:
        return
    async with SessionLocal() as db:
        if (await db.execute(select(User).where(User.email == ADMIN_EMAIL))).scalars().first():
            return
        db.add(
            User(
                nom="Admin",
                prenom="Yaarexbook",
                email=ADMIN_EMAIL,
                password_hash=await hash_password(ADMIN_PASSWORD),
                role="admin",
            )
        )
        await db.commit()
        print(f"[Yaarexbook] Administrateur créé : {ADMIN_EMAIL}")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await create_tables()
    await seed_admin()
    yield


app = FastAPI(
    title="Yaarexbook API",
    description="Réseau social de partage de documents",
    version="1.0.0",
    lifespan=lifespan,
)

# L'authentification passe par l'en-tête Authorization (pas de cookies).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(documents.router)
app.include_router(admin.router)

# Les couvertures sont publiques (affichées dans les listes). Les PDF, eux, ne le sont jamais.
app.mount("/covers", StaticFiles(directory=str(COVER_DIR)), name="covers")


@app.get("/")
async def root():
    return {"app": "Yaarexbook", "status": "ok"}


@app.get("/sw.js")
async def sw():
    return Response(content="", media_type="application/javascript")