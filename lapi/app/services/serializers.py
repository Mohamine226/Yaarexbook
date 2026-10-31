"""Construction des réponses avec leurs compteurs (likes, commentaires, abonnés...).

Les compteurs d'une page entière sont calculés avec quelques requêtes groupées,
jamais une requête par élément."""
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models import Bibliotheque, Comment, Document, Follow, Like, User
from app.schemas import DocumentOut, PublicUser


def nom_complet(user: User | None) -> str:
    return f"{user.prenom} {user.nom}".strip() if user else ""


async def _count_by(db: AsyncSession, column, ids: list[int], *where) -> dict[int, int]:
    stmt = select(column, func.count()).where(column.in_(ids), *where).group_by(column)
    return {key: n for key, n in (await db.execute(stmt)).all()}


async def build_documents(db: AsyncSession, docs: list[Document], viewer_id: int) -> list[DocumentOut]:
    if not docs:
        return []
    ids = [d.id for d in docs]

    likes = await _count_by(db, Like.document_id, ids)
    comments = await _count_by(db, Comment.document_id, ids)
    ajouts = await _count_by(db, Bibliotheque.document_id, ids)

    liked = {
        r[0]
        for r in (
            await db.execute(select(Like.document_id).where(Like.user_id == viewer_id, Like.document_id.in_(ids)))
        ).all()
    }
    in_library = {
        r[0]
        for r in (
            await db.execute(
                select(Bibliotheque.document_id).where(Bibliotheque.user_id == viewer_id, Bibliotheque.document_id.in_(ids))
            )
        ).all()
    }

    author_ids = {d.auteur_id for d in docs}
    authors = {
        u.id: u for u in (await db.execute(select(User).where(User.id.in_(author_ids)))).scalars().all()
    }

    # NOUVEAU : les auteurs que le lecteur suit (une seule requête pour toute la page)
    suivis = {
        r[0]
        for r in (
            await db.execute(
                select(Follow.followed_id).where(Follow.follower_id == viewer_id, Follow.followed_id.in_(author_ids))
            )
        ).all()
    }

    return [
        DocumentOut(
            id=d.id,
            titre=d.titre,
            description=d.description or "",
            categorie=d.categorie,
            langue=d.langue,
            domaine=d.domaine or "",
            couverture_url=f"/covers/{d.cover_file}",
            auteur_id=d.auteur_id,
            auteur_nom=nom_complet(authors.get(d.auteur_id)),
            nb_likes=likes.get(d.id, 0),
            nb_commentaires=comments.get(d.id, 0),
            nb_ajouts=ajouts.get(d.id, 0),
            liked=d.id in liked,
            dans_bibliotheque=d.id in in_library,
            # NOUVEAU : None = mon propre document (pas de bouton Suivre)
            auteur_suivi=None if d.auteur_id == viewer_id else (d.auteur_id in suivis),
            is_disabled=d.is_disabled,
            created_at=d.created_at,
        )
        for d in docs
    ]


async def build_people(db: AsyncSession, users: list[User], viewer_id: int) -> list[PublicUser]:
    if not users:
        return []
    ids = [u.id for u in users]

    documents = await _count_by(db, Document.auteur_id, ids, Document.is_disabled == False)  # noqa: E712
    abonnes = await _count_by(db, Follow.followed_id, ids)
    abonnements = await _count_by(db, Follow.follower_id, ids)
    following = {
        r[0]
        for r in (
            await db.execute(
                select(Follow.followed_id).where(Follow.follower_id == viewer_id, Follow.followed_id.in_(ids))
            )
        ).all()
    }

    return [
        PublicUser(
            id=u.id,
            nom=u.nom,
            prenom=u.prenom,
            pays=u.pays,
            profession=u.profession,
            created_at=u.created_at,
            nb_documents=documents.get(u.id, 0),
            nb_abonnes=abonnes.get(u.id, 0),
            nb_abonnements=abonnements.get(u.id, 0),
            is_following=u.id in following,
            is_me=u.id == viewer_id,
        )
        for u in users
    ]


def escape_like(text: str) -> str:
    """Pour que % et _ saisis par l'utilisateur soient cherchés tels quels."""
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")