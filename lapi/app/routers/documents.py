from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form # type: ignore
from sqlalchemy.ext.asyncio import AsyncSession # type: ignore
from sqlalchemy.future import select # type: ignore
from app.database import get_db # type: ignore
from app.models import User, Document, Bibliotheque # type: ignore
from app.schemas import DocumentResponse # type: ignore
from typing import List, Optional
from pydantic import BaseModel
from pathlib import Path
import uuid
import unicodedata, re
import os
from fastapi import UploadFile, File, Form, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from supabase import create_client, Client # type: ignore


router = APIRouter(
    prefix="/documents",
    tags=["documents"]
)

BASE_URL = os.getenv("BASE_URL")

class PaginatedDocuments(BaseModel):
    items: List[DocumentResponse]
    next_cursor: Optional[int]


# 🔹 Publier un document avec upload de fichiers

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def clean_filename(filename: str) -> str:
    nfkd = unicodedata.normalize("NFKD", filename)
    no_accents = "".join([c for c in nfkd if not unicodedata.combining(c)])
    return re.sub(r"[^a-zA-Z0-9._-]", "_", no_accents)

@router.post("/users/{vendeur_id}/upload", response_model=DocumentResponse)
async def publier_document_upload(
    vendeur_id: int,
    titre: str = Form(...),
    description: str = Form(...),
    prix: int = Form(...),
    categorie: str = Form(...),
    langue: str = Form(...),
    domaine: str = Form(...),
    pdf: UploadFile = File(...),
    couverture: UploadFile = File(...),
    db: AsyncSession = Depends(get_db)
):
    pdf_name = f"{uuid.uuid4()}_{clean_filename(pdf.filename)}"
    cover_name = f"{uuid.uuid4()}_{clean_filename(couverture.filename)}"

    # 🔹 Upload vers Supabase
    pdf_bytes = await pdf.read()
    cover_bytes = await couverture.read()

    supabase.storage.from_("uploads").upload(pdf_name, pdf_bytes)
    supabase.storage.from_("uploads").upload(cover_name, cover_bytes)

    pdf_url = supabase.storage.from_("uploads").get_public_url(pdf_name)
    cover_url = supabase.storage.from_("uploads").get_public_url(cover_name)

    nouveau_doc = Document(
        titre=titre,
        description=description,
        prix=prix,
        categorie=categorie,
        langue=langue,
        domaine=domaine,
        pdf_path=pdf_url,
        couverture_path=cover_url,
        vendeur_id=vendeur_id
    )
    db.add(nouveau_doc)
    await db.commit()
    await db.refresh(nouveau_doc)
    return nouveau_doc

@router.get("/", response_model=PaginatedDocuments)
async def get_documents(
    search: str | None = None,
    categorie: str | None = None,
    domaine: str | None = None,
    cursor: int | None = None,
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Document).where(Document.is_deleted == False)

    if search:
        search_pattern = f"%{search}%"
        stmt = stmt.where(
            Document.titre.ilike(search_pattern) |
            Document.domaine.ilike(search_pattern) |
            Document.categorie.ilike(search_pattern)
        )

    if categorie:
        stmt = stmt.where(Document.categorie == categorie)

    if domaine:
        stmt = stmt.where(Document.domaine == domaine)

    if cursor is not None:
        stmt = stmt.where(Document.id > cursor)

    stmt = stmt.order_by(Document.id).limit(limit)

    result = await db.execute(stmt)
    docs = result.scalars().all()

    next_cursor = docs[-1].id if docs else None

    return {"items": docs, "next_cursor": next_cursor}


@router.get("/admin", response_model=list[DocumentResponse])
async def get_all_documents(
    search: str | None = None,
    skip: int = 0,          # combien d’éléments sauter
    limit: int = 20,        # combien d’éléments renvoyer
    db: AsyncSession = Depends(get_db),
):
    query = select(Document).where(Document.is_deleted == False)

    # 🔹 Filtre optionnel par recherche
    if search:
        query = query.where(Document.title.ilike(f"%{search}%"))

    # 🔹 Appliquer la pagination
    query = query.offset(skip).limit(limit)

    result = await db.execute(query)
    docs = result.scalars().all()

    if not docs:
        raise HTTPException(status_code=404, detail="Aucun document trouvé")

    return docs

# 🔹 Récupérer les documents par catégorie
@router.get("/categorie/{categorie}", response_model=list[DocumentResponse])
async def get_documents_by_categorie(categorie: str, search: str | None = None, db: AsyncSession = Depends(get_db)):
    stmt = select(Document).where(Document.categorie == categorie, Document.is_deleted == False)
    if search:
        search_pattern = f"%{search}%" 
        stmt = stmt.where(
            Document.titre.ilike(search_pattern) |
            Document.domaine.ilike(search_pattern) |
            Document.langue.ilike(search_pattern)
        )
    result = await db.execute(stmt)
    return result.scalars().all()

# 🔹 Récupérer les documents d’un vendeur avec pagination
@router.get("/users/{vendeur_id}", response_model=list[DocumentResponse])
async def get_documents_by_vendeur(
    vendeur_id: int,
    skip: int = 0,          # combien d’éléments sauter
    limit: int = 20,        # combien d’éléments renvoyer
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Document)
        .where(Document.vendeur_id == vendeur_id, Document.is_deleted == False)
        .offset(skip)   # ✅ pagination offset
        .limit(limit)   # ✅ pagination limit
    )
    return result.scalars().all()

# 🔹 Récupère uniquement les livres publiés par ce vendeur avec pagination
@router.get("/vendeur", response_model=list[DocumentResponse])
async def get_documents_par_vendeur(
    vendeur_id: int,
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Document)
        .where(Document.vendeur_id == vendeur_id, Document.is_deleted == False)
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(query)
    docs = result.scalars().all()
    return docs

# 🔹 Supprimer un document
@router.delete("/{doc_id}")
async def supprimer_document(doc_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalars().first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document introuvable")

    try:
        upload_dir = Path(__file__).parent.parent / "uploads"
        if doc.pdf_path:
            pdf_file = upload_dir / Path(doc.pdf_path).name
            if pdf_file.exists():
                pdf_file.unlink()
        if doc.couverture_path:
            cover_file = upload_dir / Path(doc.couverture_path).name
            if cover_file.exists():
                cover_file.unlink()
    except Exception as e:
        print(f"Erreur suppression fichier: {e}")

    await db.delete(doc)
    await db.commit()
    return {"status": "success", "message": "Document et fichiers supprimés"}

# 🔹 Désactiver un document
@router.put("/{doc_id}/disable")
async def desactiver_document(doc_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalars().first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document introuvable")
    doc.is_deleted = True
    await db.commit()
    return {"status": "success", "message": "Document désactivé"}

# 🔹 Récupérer les 10 livres les plus populaires
@router.get("/populaires", response_model=list[DocumentResponse])
async def get_livres_populaires(db: AsyncSession = Depends(get_db)):
    stmt = (
        select(Document)
        .where(Document.achats > 0, Document.is_deleted == False)
        .order_by(Document.achats.desc())
        .limit(10)
    )
    result = await db.execute(stmt)
    return result.scalars().all()

# 🔹 Ajouter un livre dans la bibliothèque
@router.post("/users/{user_id}/bibliotheque/{doc_id}", status_code=status.HTTP_201_CREATED)
async def ajouter_dans_bibliotheque(user_id: int, doc_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    result = await db.execute(select(Document).where(Document.id == doc_id))
    document = result.scalars().first()
    if not document:
        raise HTTPException(status_code=404, detail="Document introuvable")

    if document.vendeur_id == user_id:
        raise HTTPException(status_code=400, detail="Un vendeur ne peut pas acheter son propre livre")

    result = await db.execute(
        select(Bibliotheque).where(Bibliotheque.user_id == user_id, Bibliotheque.document_id == doc_id)
    )
    deja = result.scalars().first()
    if deja:
        return {"status": "ok", "message": "Livre déjà présent dans la bibliothèque"}

    entree = Bibliotheque(user_id=user_id, document_id=doc_id)
    db.add(entree)

    document.achats = (document.achats or 0) + 1

    result = await db.execute(select(User).where(User.id == document.vendeur_id))
    vendeur = result.scalars().first()
    if vendeur:
        vendeur.ventes = (vendeur.ventes or 0) + 1

    await db.commit()
    return {"status": "created", "message": "Livre ajouté à la bibliothèque et comptabilisé chez le vendeur"}

# 🔹 Récupérer les documents vendus par un utilisateur
@router.get("/users/{vendeur_id}/ventes", response_model=list[DocumentResponse])
async def get_documents_vendus(vendeur_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == vendeur_id))
    vendeur = result.scalars().first()
    if not vendeur:
        raise HTTPException(status_code=404, detail="Vendeur introuvable")

    result = await db.execute(select(Document).where(Document.vendeur_id == vendeur_id, Document.achats > 0))
    return result.scalars().all()

# 🔹 Récupérer tous les livres de la bibliothèque d’un utilisateur
@router.get("/users/{user_id}/bibliotheque", response_model=list[DocumentResponse])
async def get_bibliotheque(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    stmt = (
        select(Document)
        .join(Bibliotheque, Bibliotheque.document_id == Document.id)
        .where(Bibliotheque.user_id == user_id)
    )
    result = await db.execute(stmt)
    return result.scalars().all()

# Recuperer les document desactivé
@router.get("/desactives", response_model=list[DocumentResponse])
async def get_documents_desactives(
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Document)
        .where(Document.is_deleted == True)
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(query)
    docs = result.scalars().all()
    return docs