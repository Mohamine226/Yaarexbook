"""Mots de passe (argon2) et authentification par jeton JWT.

Chaque connexion crée une `DeviceSession`; le jeton contient son identifiant (`sid`).
Plusieurs appareils peuvent donc être connectés au même compte en même temps,
et se déconnecter indépendamment les uns des autres."""
import asyncio
from dataclasses import dataclass
from datetime import timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.config import SECRET_KEY, TOKEN_DAYS
from app.database import get_db
from app.models import DeviceSession, User, utcnow

ALGORITHM = "HS256"
_hasher = PasswordHasher()
_bearer = HTTPBearer(auto_error=False)

# Sert à faire le même travail quand l'identifiant est inconnu (évite de révéler
# par le temps de réponse quels comptes existent).
_DUMMY_HASH = _hasher.hash("mot-de-passe-factice")


async def hash_password(password: str) -> str:
    return await asyncio.to_thread(_hasher.hash, password)


async def verify_password(password: str, hashed: str | None) -> bool:
    def _check() -> bool:
        try:
            return _hasher.verify(hashed or _DUMMY_HASH, password) and hashed is not None
        except (VerificationError, InvalidHashError):
            return False

    return await asyncio.to_thread(_check)


def create_token(user_id: int, session_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "sid": session_id,
        "exp": utcnow() + timedelta(days=TOKEN_DAYS),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


@dataclass
class Auth:
    user: User
    session: DeviceSession


async def current_auth(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> Auth:
    unauthorized = HTTPException(
        status_code=401,
        detail="Session expirée, reconnectez-vous",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload["sub"])
        session_id = int(payload["sid"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise unauthorized

    session = (
        await db.execute(
            select(DeviceSession).where(DeviceSession.id == session_id, DeviceSession.user_id == user_id)
        )
    ).scalars().first()
    if session is None:  # déconnectée ou révoquée
        raise unauthorized

    user = (await db.execute(select(User).where(User.id == user_id))).scalars().first()
    if user is None:
        raise unauthorized

    # On ne réécrit « dernière activité » qu'au plus toutes les 5 minutes.
    if utcnow() - session.last_seen > timedelta(minutes=5):
        session.last_seen = utcnow()
        await db.commit()

    return Auth(user=user, session=session)


async def current_user(auth: Auth = Depends(current_auth)) -> User:
    return auth.user


async def require_admin(user: User = Depends(current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")
    return user
