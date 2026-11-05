
"""Point d'entrée de l'API Yaarexbook."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, RedirectResponse
from sqlalchemy import select

from app.config import ADMIN_EMAIL, ADMIN_PASSWORD
from app.database import SessionLocal, close_database
from app.models import User
from app.routers import admin, auth, documents, users
from app.security import hash_password
from app.services import storage


async def seed_admin() -> None:
    """Crée le premier administrateur à partir de ADMIN_EMAIL / ADMIN_PASSWORD."""

    if not ADMIN_EMAIL or not ADMIN_PASSWORD:
        return

    async with SessionLocal() as db:
        existing_admin = (
            await db.execute(
                select(User).where(User.email == ADMIN_EMAIL)
            )
        ).scalars().first()

        if existing_admin:
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
    """Gestion du démarrage et de l'arrêt de l'API."""

    try:
        # Les tables doivent être créées par Alembic avant le démarrage.
        await seed_admin()

        yield

    finally:
        await close_database()


app = FastAPI(
    title="Yaarexbook API",
    description="Réseau social de partage de documents",
    version="1.0.0",
    lifespan=lifespan,
)


# --------------------------------------------------
# CORS
# --------------------------------------------------

# L'authentification passe par l'en-tête Authorization.

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------
# ROUTES
# --------------------------------------------------

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(documents.router)
app.include_router(admin.router)


# --------------------------------------------------
# COUVERTURES SUPABASE
# --------------------------------------------------

@app.get("/covers/{name}")
async def cover(name: str):
    """Redirige vers une URL signée d'une couverture privée Supabase."""

    url = await storage.cover_signed_url(name)

    return RedirectResponse(
        url,
        status_code=302,
        headers={
            "Cache-Control": "public, max-age=3000",
        },
    )


# --------------------------------------------------
# ROUTE PRINCIPALE
# --------------------------------------------------

@app.get("/")
async def root():
    return {
        "app": "Yaarexbook",
        "status": "ok",
    }


# --------------------------------------------------
# SERVICE WORKER
# --------------------------------------------------

@app.get("/sw.js")
async def sw():
    return Response(
        content="",
        media_type="application/javascript",
    )
