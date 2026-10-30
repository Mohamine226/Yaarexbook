from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Follow, User
from app.schemas import FollowOut, Page, PublicUser
from app.security import current_user
from app.services.serializers import build_people, escape_like

router = APIRouter(prefix="/users", tags=["users"])


async def _people_page(db: AsyncSession, stmt, cursor: int, limit: int, viewer: User) -> Page[PublicUser]:
    users = list((await db.execute(stmt.offset(cursor).limit(limit))).scalars().all())
    items = await build_people(db, users, viewer.id)
    return Page(items=items, next_cursor=cursor + limit if len(users) == limit else None)


@router.get("/search", response_model=Page[PublicUser])
async def search_people(
    q: str = Query(min_length=2, max_length=100),
    cursor: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    pattern = f"%{escape_like(q.strip())}%"
    stmt = (
        select(User)
        .where(
            or_(
                User.nom.ilike(pattern, escape="\\"),
                User.prenom.ilike(pattern, escape="\\"),
                User.profession.ilike(pattern, escape="\\"),
            )
        )
        .order_by(User.id)
    )
    return await _people_page(db, stmt, cursor, limit, viewer)


@router.get("/{user_id}/profile", response_model=PublicUser)
async def profile(user_id: int, db: AsyncSession = Depends(get_db), viewer: User = Depends(current_user)):
    user = (await db.execute(select(User).where(User.id == user_id))).scalars().first()
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return (await build_people(db, [user], viewer.id))[0]


async def _followers(db: AsyncSession, user_id: int) -> int:
    return (await db.execute(select(func.count()).select_from(Follow).where(Follow.followed_id == user_id))).scalar() or 0


@router.post("/{user_id}/follow", response_model=FollowOut)
async def follow(user_id: int, db: AsyncSession = Depends(get_db), me: User = Depends(current_user)):
    if user_id == me.id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous suivre vous-même")
    if (await db.execute(select(User.id).where(User.id == user_id))).first() is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    exists = (
        await db.execute(select(Follow).where(Follow.follower_id == me.id, Follow.followed_id == user_id))
    ).scalars().first()
    if exists is None:
        db.add(Follow(follower_id=me.id, followed_id=user_id))
        await db.commit()
    return FollowOut(is_following=True, nb_abonnes=await _followers(db, user_id))


@router.delete("/{user_id}/follow", response_model=FollowOut)
async def unfollow(user_id: int, db: AsyncSession = Depends(get_db), me: User = Depends(current_user)):
    await db.execute(Follow.__table__.delete().where(Follow.follower_id == me.id, Follow.followed_id == user_id))
    await db.commit()
    return FollowOut(is_following=False, nb_abonnes=await _followers(db, user_id))


@router.get("/{user_id}/abonnes", response_model=Page[PublicUser])
async def abonnes(
    user_id: int,
    cursor: int = Query(0, ge=0),
    limit: int = Query(30, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    stmt = (
        select(User)
        .join(Follow, Follow.follower_id == User.id)
        .where(Follow.followed_id == user_id)
        .order_by(Follow.id.desc())
    )
    return await _people_page(db, stmt, cursor, limit, viewer)


@router.get("/{user_id}/abonnements", response_model=Page[PublicUser])
async def abonnements(
    user_id: int,
    cursor: int = Query(0, ge=0),
    limit: int = Query(30, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    viewer: User = Depends(current_user),
):
    stmt = (
        select(User)
        .join(Follow, Follow.followed_id == User.id)
        .where(Follow.follower_id == user_id)
        .order_by(Follow.id.desc())
    )
    return await _people_page(db, stmt, cursor, limit, viewer)
