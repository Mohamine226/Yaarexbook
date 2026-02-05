from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.user import User # type: ignore
from app.schemas import UserCreate # type: ignore
from passlib.context import CryptContext
from datetime import datetime

# Contexte pour hasher les mots de passe
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str):
    return pwd_context.verify(plain_password, hashed_password)

# 🔹 Créer un utilisateur
async def create_user(db: AsyncSession, user: UserCreate):
    # Vérifier si l'email existe déjà
    result = await db.execute(select(User).where(User.email == user.email))
    existing_email = result.scalars().first()
    if existing_email:
        return {"error": "Cet email est déjà utilisé ❌"}

    # Vérifier si le numéro existe déjà
    result = await db.execute(select(User).where(User.telephone == user.telephone))
    existing_phone = result.scalars().first()
    if existing_phone:
        return {"error": "Ce numéro est déjà utilisé ❌"}

    db_user = User(
        nom=user.nom.strip(),
        prenom=user.prenom.strip(),
        email=user.email.strip(),
        telephone=user.telephone.strip(),
        pays=user.pays.strip(),
        profession=user.profession.strip(),
        password=hash_password(user.password),  # ✅ mot de passe hashé
        role=getattr(user, "role", "acheteur"),  # rôle par défaut
        ventes=0,  # compteur initial
        date_publication=datetime.utcnow()  # date de création
    )

    try:
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
        return {"success": "Utilisateur créé avec succès ✅", "user": db_user}
    except Exception as e:
        await db.rollback()
        return {"error": f"Erreur lors de la création : {str(e)}"}

# 🔹 Récupérer un utilisateur par email
async def get_user_by_email(db: AsyncSession, email: str):
    result = await db.execute(select(User).where(User.email == email))
    return result.scalars().first()

# 🔹 Récupérer un utilisateur par ID
async def get_user_by_id(db: AsyncSession, user_id: int):
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalars().first()

# 🔹 Supprimer un utilisateur
async def delete_user(db: AsyncSession, user_id: int):
    user = await get_user_by_id(db, user_id)
    if user:
        await db.delete(user)
        await db.commit()
        return True
    return False