from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Bibliotheque, Comment, DeviceSession, Document, Follow, Like, User, utcnow
from app.schemas import DocumentOut, Message, Page, RoleIn, StatsOut, UserOut
from app.security import require_admin
from app.services import storage
from app.services.serializers import build_documents, escape_like

router = APIRouter(prefix="/admin", tags=["admin"])


async def _count(db: AsyncSession, stmt) -> int:
    return (await db.execute(stmt)).scalar() or 0


@router.get("/stats", response_model=StatsOut)
async def stats(db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    now = utcnow()
    n = lambda model: select(func.count()).select_from(model)  # noqa: E731
    return StatsOut(
        total_utilisateurs=await _count(db, n(User)),
        total_documents=await _count(db, n(Document)),
        documents_desactives=await _count(db, n(Document).where(Document.is_disabled == True)),  # noqa: E712
        total_likes=await _count(db, n(Like)),
        total_commentaires=await _count(db, n(Comment)),
        total_abonnements=await _count(db, n(Follow)),
        ajouts_bibliotheque=await _count(db, n(Bibliotheque)),
        connexions_actives=await _count(db, n(DeviceSession)),
        nouveaux_documents_mois=await _count(db, n(Document).where(Document.created_at >= datetime(now.year, now.month, 1))),
        nouveaux_documents_annee=await _count(db, n(Document).where(Document.created_at >= datetime(now.year, 1, 1))),
    )


# ------------------------------------------------------------------ membres
@router.get("/users", response_model=Page[UserOut])
async def users(
    search: str | None = None,
    cursor: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    stmt = select(User)
    if search and search.strip():
        p = f"%{escape_like(search.strip())}%"
        stmt = stmt.where(
            or_(User.nom.ilike(p, escape="\\"), User.prenom.ilike(p, escape="\\"), User.email.ilike(p, escape="\\"))
        )
    rows = list((await db.execute(stmt.order_by(User.id.desc()).offset(cursor).limit(limit))).scalars().all())
    return Page(items=rows, next_cursor=cursor + limit if len(rows) == limit else None)


@router.put("/users/{user_id}/role", response_model=UserOut)
async def set_role(
    user_id: int, payload: RoleIn, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)
):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas modifier votre propre rôle")
    user = (await db.execute(select(User).where(User.id == user_id))).scalars().first()
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    user.role = payload.role
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/users/{user_id}", response_model=Message)
async def delete_user(user_id: int, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Utilisez « Supprimer mon compte » pour votre propre compte")
    user = (await db.execute(select(User).where(User.id == user_id))).scalars().first()
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    docs = (await db.execute(select(Document).where(Document.auteur_id == user_id))).scalars().all()
    pdfs, covers = [d.pdf_file for d in docs], [d.cover_file for d in docs]
    await db.delete(user)
    await db.commit()
    storage.delete_files(pdfs, covers)
    return Message(message="Membre supprimé")


# ------------------------------------------------------------------ documents
@router.get("/documents", response_model=Page[DocumentOut])
async def documents(
    etat: str = Query("actifs", pattern="^(actifs|desactives|tous)$"),
    search: str | None = None,
    cursor: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    stmt = select(Document)
    if etat == "actifs":
        stmt = stmt.where(Document.is_disabled == False)  # noqa: E712
    elif etat == "desactives":
        stmt = stmt.where(Document.is_disabled == True)  # noqa: E712
    if search and search.strip():
        stmt = stmt.where(Document.titre.ilike(f"%{escape_like(search.strip())}%", escape="\\"))
    if cursor:
        stmt = stmt.where(Document.id < cursor)
    docs = list((await db.execute(stmt.order_by(Document.id.desc()).limit(limit))).scalars().all())
    items = await build_documents(db, docs, admin.id)
    return Page(items=items, next_cursor=docs[-1].id if len(docs) == limit else None)


async def _set_disabled(db: AsyncSession, doc_id: int, disabled: bool) -> Message:
    doc = (await db.execute(select(Document).where(Document.id == doc_id))).scalars().first()
    if doc is None:
        raise HTTPException(status_code=404, detail="Document introuvable")
    doc.is_disabled = disabled
    await db.commit()
    return Message(message="Document désactivé" if disabled else "Document réactivé")


@router.put("/documents/{doc_id}/disable", response_model=Message)
async def disable(doc_id: int, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    return await _set_disabled(db, doc_id, True)


@router.put("/documents/{doc_id}/enable", response_model=Message)
async def enable(doc_id: int, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    return await _set_disabled(db, doc_id, False)
