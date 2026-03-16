from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from datetime import datetime
from pydantic import BaseModel
from app.database import get_db
from app.models import User, Document, Bibliotheque # type: ignore

router = APIRouter(
    prefix="/api/statistiques",
    tags=["statistiques"]
)

class StatistiquesGlobales(BaseModel):
    total_utilisateurs: int
    total_vendeurs: int
    total_acheteurs: int
    total_documents: int
    achats_mois: int
    achats_annee: int
    achats_depuis_creation: int

@router.get("/global", response_model=StatistiquesGlobales)
async def get_statistiques_globales(db: AsyncSession = Depends(get_db)):
    # 🔹 Comptages réels depuis la base
    total_utilisateurs = (await db.execute(select(func.count()).select_from(User))).scalar()
    total_vendeurs = (await db.execute(select(func.count()).select_from(User).where(User.role == "vendeur"))).scalar()
    total_acheteurs = (await db.execute(select(func.count()).select_from(User).where(User.role == "Lecteur"))).scalar()
    total_documents = (await db.execute(select(func.count()).select_from(Document))).scalar()

    # 🔹 Statistiques achats (via Bibliotheque)
    achats_mois = (
        await db.execute(
            select(func.count()).select_from(Bibliotheque)
            .where(func.extract("month", Bibliotheque.date_ajout) == datetime.now().month)
            .where(func.extract("year", Bibliotheque.date_ajout) == datetime.now().year)
        )
    ).scalar()

    achats_annee = (
        await db.execute(
            select(func.count()).select_from(Bibliotheque)
            .where(func.extract("year", Bibliotheque.date_ajout) == datetime.now().year)
        )
    ).scalar()

    achats_depuis_creation = (await db.execute(select(func.count()).select_from(Bibliotheque))).scalar()

    return StatistiquesGlobales(
        total_utilisateurs=total_utilisateurs or 0,
        total_vendeurs=total_vendeurs or 0,
        total_acheteurs=total_acheteurs or 0,
        total_documents=total_documents or 0,
        achats_mois=achats_mois or 0,
        achats_annee=achats_annee or 0,
        achats_depuis_creation=achats_depuis_creation or 0
    )