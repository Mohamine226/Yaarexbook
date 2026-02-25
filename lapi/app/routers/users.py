import random
from fastapi import APIRouter, Depends, HTTPException # type: ignore
from sqlalchemy.ext.asyncio import AsyncSession # type: ignore
from sqlalchemy.future import select # type: ignore
from app.database import get_db
from app.models.user import User
from app.models import PasswordResetCode, transaction
from app.schemas import RoleUpdate, ForgotPasswordRequest
from datetime import datetime, timedelta
import re
from app.services.messaging import send_reset_email, send_reset_sms
from passlib.context import CryptContext
import app.models as models 



router = APIRouter(prefix="/users", tags=["users"])


pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)



def is_password_valid(password: str) -> bool:
    """
    Vérifie que le mot de passe contient :
    - au moins 8 caractères
    - une majuscule
    - une minuscule
    - un chiffre
    - un caractère spécial
    """
    regex = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$'
    return re.match(regex, password) is not None



# 🔹 Vérifier si un utilisateur existe par email ou téléphone
@router.get("/check")
async def check_user(identifier: str, db: AsyncSession = Depends(get_db)):
    """
    Vérifie si un utilisateur existe par email ou numéro de téléphone
    """
    result = await db.execute(
        select(User).where((User.email == identifier) | (User.telephone == identifier))
    )
    user = result.scalars().first()
    return {"exists": bool(user)}

# 🔹 Liste des utilisateurs
@router.get("/")
async def list_users(
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).offset(skip).limit(limit)
    )
    users = result.scalars().all()
    return users   # ✅ renvoie directement les objets User




# 🔹 Supprimer un utilisateur par ID
@router.delete("/{user_id}")
async def delete_user(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    await db.delete(user)
    await db.commit()
    return {"status": "success", "message": f"Utilisateur {user_id} supprimé"}


# 🔹 Mot de passe oublié (email ou numéro)
# 1. Demande de reset
@router.post("/forgot-password")
async def forgot_password(payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    identifier = payload.identifier

    # 🔹 Vérifier si l'utilisateur existe
    result = await db.execute(
        select(User).where((User.email == identifier) | (User.telephone == identifier))
    )
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # 🔹 Générer le code
    code = str(random.randint(100000, 999999))
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    reset_code = PasswordResetCode(user_id=user.id, code=code, expires_at=expires_at)
    db.add(reset_code)
    await db.commit()

    #  Affichage du code dans la console (DEV uniquement)
    print(f" Code de réinitialisation pour {identifier}: {code}")

    #  Envoi par email si identifiant = email
    if identifier == user.email:
        await send_reset_email(user.email, code)

    #  Envoi par SMS si identifiant = téléphone
    else:
        send_reset_sms(user.telephone, code)

    return {"status": "success", "message": "Code généré et affiché en console"}

# 🔹 Changement de mot de passe
@router.post("/change-password")
async def change_password(user_id: int, old_password: str, new_password: str, db: AsyncSession = Depends(get_db)):
    if not is_password_valid(new_password):
        raise HTTPException(status_code=400, detail="Mot de passe trop faible")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    if not verify_password(old_password, user.password):
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect")

    # Stockage du nouveau mot de passe hashé
    user.password = hash_password(new_password)

    await db.commit()
    await db.refresh(user)

    return {"status": "success", "message": "Mot de passe changé avec succès"}


# 🔹 Changer le rôle (acheteur → vendeur définitif)
@router.put("/{user_id}/change-role")
async def change_role(user_id: int, payload: RoleUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # Vérifie le mot de passe
    if not verify_password(payload.password, user.password):
        raise HTTPException(status_code=400, detail="Mot de passe incorrect")

    # Empêche de revenir acheteur si déjà vendeur
    if user.role == "vendeur":
        raise HTTPException(status_code=400, detail="Impossible de revenir acheteur")

    # Vérifie que le rôle demandé est valide
    if payload.new_role not in ["acheteur", "vendeur"]:
        raise HTTPException(status_code=400, detail="Rôle invalide")

    # 🔹 Si le nouveau rôle est vendeur
    if payload.new_role == "vendeur":
        user.role = "vendeur"
        await db.commit()
        await db.refresh(user)

        # 🔹 Créer automatiquement un wallet pour ce vendeur
        new_wallet = transaction.Wallet(user_id=user.id, solde=0.0)  # ✅ correction ici
        db.add(new_wallet)
        await db.commit()
        await db.refresh(new_wallet)

        return {
            "status": "success",
            "message": "Rôle changé en vendeur et wallet créé",
            "wallet_id": new_wallet.id,
            "solde": new_wallet.solde
        }

    return {"status": "error", "message": "Le rôle ne peut être modifié que vers vendeur"}