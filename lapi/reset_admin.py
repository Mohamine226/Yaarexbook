"""Crée ou répare un compte administrateur.

Usage (depuis le dossier lapi) :
    python reset_admin.py votre@email.com VotreMotDePasse
"""
import asyncio
import sys

from sqlalchemy import select

from app.database import SessionLocal, create_tables
from app.models import User
from app.security import hash_password


async def main(email: str, password: str) -> None:
    await create_tables()
    email = email.strip().lower()
    async with SessionLocal() as db:
        user = (await db.execute(select(User).where(User.email == email))).scalars().first()
        if user is None:
            db.add(
                User(
                    nom="Admin",
                    prenom="Yaarexbook",
                    email=email,
                    password_hash=await hash_password(password),
                    role="admin",
                )
            )
            print(f"Administrateur créé : {email}")
        else:
            user.password_hash = await hash_password(password)
            user.role = "admin"
            print(f"Mot de passe réinitialisé et rôle admin donné à : {email}")
        await db.commit()


if len(sys.argv) != 3:
    sys.exit("Usage : python reset_admin.py votre@email.com VotreMotDePasse")
asyncio.run(main(sys.argv[1], sys.argv[2]))