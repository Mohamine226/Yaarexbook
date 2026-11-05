
import re

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import MAX_COVER_BYTES, MAX_PDF_BYTES
from app.database import get_db
from app.models import Bibliotheque, Comment, Document, Follow, Like, User
from app.schemas import CommentIn, CommentOut, DocumentOut, LikeOut, Message, Page
from app.security import current_user
from app.services import storage
from app.services.serializers import build_documents, escape_like, nom_complet

router = APIRouter(prefix="/documents", tags=["documents"])

VISIBLE = Document.is_disabled == False  # noqa: E712


async def get_visible_document(
    db: AsyncSession,
    doc_id: int,
    viewer: User,
) -> Document:
    """Un document désactivé n'existe plus pour les membres ; les admins le voient encore."""

    doc = (
        await db.execute(
            select(Document).where(Document.id == doc_id)
        )
    ).scalars().first()

    if doc is None or (doc.is_disabled and viewer.role != "admin"):
        raise HTTPException(status_code=404, detail="Document introuvable")

    return doc


async def _id_page(
    db: AsyncSession,
    stmt,
    cursor: int,
    limit: int,
    viewer: User,
) -> Page[DocumentOut]:
    """Page par curseur, du plus récent au plus ancien."""

    if cursor:
        stmt = stmt.where(Document.id < cursor)

    docs = list(
        (
            await db.execute(
                stmt.order_by(Document.id.desc()).limit(limit)
            )
        ).scalars().all()
    )

    items = await build_documents(db, docs, viewer.id)

    return Page(
        items=items,
        next_cursor=docs[-1].id if len(docs) == limit else None,
    )


# ------------------------------------------------------------------
# PUBLICATION
# ------------------------------------------------------------------

@router.post("", response_model=DocumentOut, status_code=201)
async def publier(
    titre: str = Form(..., min_length=1, max_length=200),
    description: str = Form("", max_length=5000),
    categorie: str = Form(..., min_length=1, max_length=60),
    langue: str = Form(..., min_length=1, max_length=40),
    domaine: str = Form("", max_length=100),
    pdf: UploadFile = File(...),
    couverture: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    """Tout membre connecté peut publier."""

    pdf_bytes = await pdf.read(MAX_PDF_BYTES + 1)
    cover_bytes = await couverture.read(MAX_COVER_BYTES + 1)

    if len(pdf_bytes) > MAX_PDF_BYTES:
        raise HTTPException(
            status_code=413,
            detail="PDF trop volumineux (50 Mo maximum)",
        )

    if len(cover_bytes) > MAX_COVER_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Couverture trop volumineuse (5 Mo maximum)",
        )

    # Enregistrement du PDF dans Supabase Storage
    pdf_file = await storage.save_pdf(pdf_bytes)

    try:
        # Enregistrement de la couverture dans Supabase Storage
        cover_file = await storage.save_cover(cover_bytes)

    except Exception:
        await storage.delete_files(pdf_files=[pdf_file])
        raise

    try:
        doc = Document(
            titre=titre.strip(),
            description=description.strip(),
            categorie=categorie.strip(),
            langue=langue.strip(),
            domaine=domaine.strip(),
            pdf_file=pdf_file,
            cover_file=cover_file,
            auteur_id=user.id,
        )

        db.add(doc)
        await db.commit()
        await db.refresh(doc)

    except Exception:
        await db.rollback()

        # Nettoyage des fichiers si l'enregistrement en base échoue
        await storage.delete_files(
            pdf_files=[pdf_file],
            cover_files=[cover_file],
        )
        raise

    return (await build_documents(db, [doc], user.id))[0]


# ------------------------------------------------------------------
# LISTES
# ------------------------------------------------------------------

@router.get("", response_model=Page[DocumentOut])
async def rechercher(
    search: str | None = None,
    categorie: str | None = None,
    langue: str | None = None,
    auteur_id: int | None = None,
    cursor: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    """Recherche dans les documents et les informations des auteurs."""

    stmt = select(Document).where(VISIBLE)

    if search and search.strip():
        pattern = f"%{escape_like(search.strip())}%"

        stmt = stmt.join(
            User,
            User.id == Document.auteur_id,
        ).where(
            or_(
                Document.titre.ilike(pattern, escape="\\"),
                Document.description.ilike(pattern, escape="\\"),
                Document.domaine.ilike(pattern, escape="\\"),
                Document.categorie.ilike(pattern, escape="\\"),
                User.nom.ilike(pattern, escape="\\"),
                User.prenom.ilike(pattern, escape="\\"),
            )
        )

    if categorie:
        stmt = stmt.where(Document.categorie == categorie)

    if langue:
        stmt = stmt.where(Document.langue == langue)

    if auteur_id is not None:
        stmt = stmt.where(Document.auteur_id == auteur_id)

    return await _id_page(db, stmt, cursor, limit, viewer)


@router.get("/feed", response_model=Page[DocumentOut])
async def fil_abonnements(
    cursor: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    """Documents publiés par les personnes que l'on suit."""

    followed = select(Follow.followed_id).where(
        Follow.follower_id == viewer.id
    )

    stmt = select(Document).where(
        VISIBLE,
        Document.auteur_id.in_(followed),
    )

    return await _id_page(db, stmt, cursor, limit, viewer)


@router.get("/populaires", response_model=Page[DocumentOut])
async def populaires(
    cursor: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    """Les plus aimés d'abord."""

    stmt = (
        select(Document)
        .join(Like, Like.document_id == Document.id)
        .where(VISIBLE)
        .group_by(Document.id)
        .order_by(
            func.count(Like.id).desc(),
            Document.id.desc(),
        )
        .offset(cursor)
        .limit(limit)
    )

    docs = list(
        (await db.execute(stmt)).scalars().all()
    )

    items = await build_documents(db, docs, viewer.id)

    return Page(
        items=items,
        next_cursor=cursor + limit if len(docs) == limit else None,
    )


# ------------------------------------------------------------------
# BIBLIOTHÈQUE PERSONNELLE
# ------------------------------------------------------------------

@router.get("/bibliotheque", response_model=list[DocumentOut])
async def ma_bibliotheque(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    """La liste complète : l'application la garde en local."""

    stmt = (
        select(Document)
        .join(
            Bibliotheque,
            Bibliotheque.document_id == Document.id,
        )
        .where(
            Bibliotheque.user_id == user.id,
            VISIBLE,
        )
        .order_by(Bibliotheque.id.desc())
    )

    docs = list(
        (await db.execute(stmt)).scalars().all()
    )

    return await build_documents(db, docs, user.id)


@router.post(
    "/bibliotheque/{doc_id}",
    response_model=Message,
    status_code=201,
)
async def ajouter_a_la_bibliotheque(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    await get_visible_document(db, doc_id, user)

    exists = (
        await db.execute(
            select(Bibliotheque).where(
                Bibliotheque.user_id == user.id,
                Bibliotheque.document_id == doc_id,
            )
        )
    ).scalars().first()

    if exists is None:
        db.add(
            Bibliotheque(
                user_id=user.id,
                document_id=doc_id,
            )
        )
        await db.commit()

    return Message(message="Document ajouté à la bibliothèque")


@router.delete(
    "/bibliotheque/{doc_id}",
    response_model=Message,
)
async def retirer_de_la_bibliotheque(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    await db.execute(
        delete(Bibliotheque).where(
            Bibliotheque.user_id == user.id,
            Bibliotheque.document_id == doc_id,
        )
    )

    await db.commit()

    return Message(message="Document retiré de la bibliothèque")


# ------------------------------------------------------------------
# SUPPRESSION DES COMMENTAIRES
# ------------------------------------------------------------------

@router.delete(
    "/commentaires/{comment_id}",
    response_model=Message,
)
async def supprimer_commentaire(
    comment_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    """Suppression par son auteur, l'auteur du document ou un admin."""

    comment = (
        await db.execute(
            select(Comment).where(Comment.id == comment_id)
        )
    ).scalars().first()

    if comment is None:
        raise HTTPException(
            status_code=404,
            detail="Commentaire introuvable",
        )

    doc = (
        await db.execute(
            select(Document).where(
                Document.id == comment.document_id
            )
        )
    ).scalars().first()

    allowed = (
        user.role == "admin"
        or comment.user_id == user.id
        or (doc is not None and doc.auteur_id == user.id)
    )

    if not allowed:
        raise HTTPException(
            status_code=403,
            detail="Suppression non autorisée",
        )

    await db.delete(comment)
    await db.commit()

    return Message(message="Commentaire supprimé")


# ------------------------------------------------------------------
# DÉTAIL D'UN DOCUMENT
# ------------------------------------------------------------------

@router.get("/{doc_id}", response_model=DocumentOut)
async def detail(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    doc = await get_visible_document(db, doc_id, viewer)

    return (await build_documents(db, [doc], viewer.id))[0]


# ------------------------------------------------------------------
# TÉLÉCHARGEMENT D'UN PDF PRIVÉ
# ------------------------------------------------------------------

@router.get("/{doc_id}/fichier")
async def telecharger(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    """Le PDF n'est jamais public : authentification obligatoire."""

    doc = await get_visible_document(db, doc_id, viewer)

    # Lecture du PDF depuis le bucket privé Supabase
    pdf_bytes = await storage.read_pdf(doc.pdf_file)

    safe_name = (
        re.sub(r"[^A-Za-z0-9._-]+", "_", doc.titre).strip("_")
        or "document"
    )

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{safe_name}.pdf"',
        },
    )


# ------------------------------------------------------------------
# SUPPRESSION D'UN DOCUMENT
# ------------------------------------------------------------------

@router.delete("/{doc_id}", response_model=Message)
async def supprimer(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    doc = (
        await db.execute(
            select(Document).where(Document.id == doc_id)
        )
    ).scalars().first()

    if doc is None:
        raise HTTPException(
            status_code=404,
            detail="Document introuvable",
        )

    if doc.auteur_id != user.id and user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Vous ne pouvez supprimer que vos propres documents",
        )

    pdf_file = doc.pdf_file
    cover_file = doc.cover_file

    await db.delete(doc)

    await db.commit()

    # Suppression des fichiers dans Supabase Storage
    await storage.delete_files(
        pdf_files=[pdf_file],
        cover_files=[cover_file],
    )

    return Message(message="Document supprimé")


# ------------------------------------------------------------------
# LIKES
# ------------------------------------------------------------------

async def _like_state(
    db: AsyncSession,
    doc_id: int,
    liked: bool,
) -> LikeOut:

    n = (
        await db.execute(
            select(func.count())
            .select_from(Like)
            .where(Like.document_id == doc_id)
        )
    ).scalar() or 0

    return LikeOut(
        liked=liked,
        nb_likes=n,
    )


@router.post("/{doc_id}/like", response_model=LikeOut)
async def aimer(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    await get_visible_document(db, doc_id, user)

    exists = (
        await db.execute(
            select(Like).where(
                Like.user_id == user.id,
                Like.document_id == doc_id,
            )
        )
    ).scalars().first()

    if exists is None:
        db.add(
            Like(
                user_id=user.id,
                document_id=doc_id,
            )
        )
        await db.commit()

    return await _like_state(db, doc_id, True)


@router.delete("/{doc_id}/like", response_model=LikeOut)
async def ne_plus_aimer(
    doc_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    await db.execute(
        delete(Like).where(
            Like.user_id == user.id,
            Like.document_id == doc_id,
        )
    )

    await db.commit()

    return await _like_state(db, doc_id, False)


# ------------------------------------------------------------------
# COMMENTAIRES
# ------------------------------------------------------------------

@router.get(
    "/{doc_id}/commentaires",
    response_model=Page[CommentOut],
)
async def commentaires(
    doc_id: int,
    cursor: int = Query(0, ge=0),
    limit: int = Query(30, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    await get_visible_document(db, doc_id, viewer)

    stmt = (
        select(Comment, User)
        .join(User, User.id == Comment.user_id)
        .where(Comment.document_id == doc_id)
    )

    if cursor:
        stmt = stmt.where(Comment.id < cursor)

    rows = (
        await db.execute(
            stmt.order_by(Comment.id.desc()).limit(limit)
        )
    ).all()

    items = [
        CommentOut(
            id=c.id,
            document_id=c.document_id,
            user_id=c.user_id,
            auteur_nom=nom_complet(u),
            contenu=c.contenu,
            created_at=c.created_at,
        )
        for c, u in rows
    ]

    return Page(
        items=items,
        next_cursor=items[-1].id if len(items) == limit else None,
    )


@router.post(
    "/{doc_id}/commentaires",
    response_model=CommentOut,
    status_code=201,
)
async def commenter(
    doc_id: int,
    payload: CommentIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(current_user),
):
    await get_visible_document(db, doc_id, user)

    contenu = payload.contenu.strip()

    if not contenu:
        raise HTTPException(
            status_code=400,
            detail="Le commentaire est vide",
        )

    comment = Comment(
        user_id=user.id,
        document_id=doc_id,
        contenu=contenu,
    )

    db.add(comment)

    await db.commit()
    await db.refresh(comment)

    return CommentOut(
        id=comment.id,
        document_id=doc_id,
        user_id=user.id,
        auteur_nom=nom_complet(user),
        contenu=comment.contenu,
        created_at=comment.created_at,
    )
