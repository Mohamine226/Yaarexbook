from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import update
from pydantic import BaseModel, EmailStr
from typing import Optional
from app.database import AsyncSessionLocal, get_db, engine
from app.models.user import User, Base
from jose import jwt, JWTError
from sqlalchemy import delete
from datetime import datetime, timedelta
from fastapi.security import OAuth2PasswordBearer
from app.models import UserSession, VerificationCode, PasswordResetCode
from app.schemas import UserCreate, LoginRequest, ProfileUpdate, PasswordUpdate, VerifyResetCodeRequest, UserStatusResponse, LogoutRequest, VerifyRequest, UserCreateAdmin, ResendCodeRequest
from passlib.context import CryptContext

# ⚠️ Création des tables (à faire au démarrage, pas dans les endpoints)
# En async, il vaut mieux utiliser alembic pour les migrations
# Base.metadata.create_all(bind=engine)  # à éviter en async

router = APIRouter(prefix="/auth", tags=["auth"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)


# -----------------------------
# Config JWT
# -----------------------------
SECRET_KEY = "ton_secret_key"   # ⚠️ change avec une vraie clé secrète
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> str:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Token invalide")
        return email
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")
    
async def authenticate_user(db, email: str, password: str):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()
    if not user or not verify_password(password, user.password):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    return user


# -----------------------------
# Endpoints
# -----------------------------
@router.post("/admin")
async def register(user: UserCreateAdmin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == user.email))
    exists = result.scalars().first()
    if exists:
        return {"status": "error", "message": "Email déjà utilisé"}

    db_user = User(
        nom=user.nom,
        prenom=user.prenom,
        email=user.email,
        telephone=user.telephone,
        pays=user.pays,
        profession=user.profession,
        password=hash_password(user.password),
        role= user.role,
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)

    return {
        "status": "success",
        "message": "Inscription réussie",
        "user": {
            "id": db_user.id,
            "nom": db_user.nom,
            "prenom": db_user.prenom,
            "email": db_user.email,
            "telephone": db_user.telephone,
            "pays": db_user.pays,
            "profession": db_user.profession,
            "role": db_user.role,
        }
    }

# Endpoints du code verifiaction
@router.post("/pre_register")
async def pre_register(user: UserCreate, db: AsyncSession = Depends(get_db)):
    # Vérifier si l'email existe déjà
    result = await db.execute(select(User).where(User.email == user.email))
    exists = result.scalars().first()
    if exists:
        return {"status": "error", "message": "Email déjà utilisé"}

    # Créer l'utilisateur en attente de vérification
    db_user = User(
        nom=user.nom,
        prenom=user.prenom,
        email=user.email,
        telephone=user.telephone,
        pays=user.pays,
        profession=user.profession,
        password=hash_password(user.password),
        is_verified=False
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)

    # Générer un code à 6 chiffres
    import random
    from datetime import datetime, timedelta
    code = str(random.randint(100000, 999999))
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    verification = VerificationCode(user_id=db_user.id, code=code, expires_at=expires_at)
    db.add(verification)
    await db.commit()

    # 🔹 Afficher le code dans la console
    print(f"✅ Code de vérification pour {db_user.email} : {code}")

    # En local : tu peux aussi le retourner dans la réponse pour tester
    return {"status": "success", "message": "Code généré", "code": code}

# Verification du code

@router.post("/verify")
async def verify(payload: VerifyRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    result = await db.execute(
        select(VerificationCode).where(
            (VerificationCode.user_id == user.id) & (VerificationCode.code == payload.code)
        )
    )
    verification = result.scalars().first()
    if not verification:
        return {"status": "error", "message": "Code invalide"}

    from datetime import datetime
    if verification.expires_at < datetime.utcnow():
        return {"status": "error", "message": "Code expiré"}

    # ✅ Valider l'inscription
    user.is_verified = True
    await db.commit()

    return {"status": "success", "message": "Inscription validée"}


# Renvoyer le code 
@router.post("/resend_code")
async def resend_code(payload: ResendCodeRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    import random
    from datetime import datetime, timedelta
    new_code = str(random.randint(100000, 999999))
    expires_at = datetime.utcnow() + timedelta(minutes=3)

    result = await db.execute(select(VerificationCode).where(VerificationCode.user_id == user.id))
    verification = result.scalars().first()

    if verification:
        verification.code = new_code
        verification.expires_at = expires_at
    else:
        verification = VerificationCode(user_id=user.id, code=new_code, expires_at=expires_at)
        db.add(verification)

    await db.commit()

    print(f"🔄 Nouveau code pour {user.email} : {new_code}")

    return {"status": "success", "message": "Nouveau code envoyé", "code": new_code}

@router.put("/update-profile")
async def update_profile(payload: ProfileUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")

    user.pays = payload.pays
    user.profession = payload.profession
    await db.commit()
    await db.refresh(user)

    return {
        "status": "success",
        "message": "Profil mis à jour",
        "user": {
            "id": user.id,
            "nom": user.nom,
            "prenom": user.prenom,
            "email": user.email,
            "telephone": user.telephone,
            "pays": user.pays,
            "profession": user.profession,
        }
    }

# 2. Vérification du code
@router.post("/verify-reset-code")
async def verify_reset_code(payload: VerifyResetCodeRequest, db: AsyncSession = Depends(get_db)):
    identifier = payload.identifier
    code = payload.code

    print(f"🔎 Vérification du code pour identifiant: {identifier}, code reçu: {code}")

    result = await db.execute(
        select(User).where((User.email == identifier) | (User.telephone == identifier))
    )
    user = result.scalars().first()
    print(f"➡️ Utilisateur trouvé: {user.email if user else 'aucun'}")

    if not user:
        print("❌ Aucun utilisateur trouvé")
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    reset_code = await db.execute(
        select(PasswordResetCode).where(
            PasswordResetCode.user_id == user.id,
            PasswordResetCode.code == code,
            PasswordResetCode.expires_at > datetime.utcnow()
        )
    )
    reset_code = reset_code.scalars().first()
    print(f"➡️ Code trouvé en base: {reset_code.code if reset_code else 'aucun'}")

    if not reset_code:
        print("❌ Code invalide ou expiré")
        raise HTTPException(status_code=400, detail="Code invalide ou expiré")

    print("✅ Code validé avec succès")
    return {"status": "success", "message": "Code validé"}

# 3. Mise à jour du mot de passe
@router.put("/set-password")
async def set_password(payload: PasswordUpdate, db: AsyncSession = Depends(get_db)):
    identifier = payload.identifier
    code = payload.code
    new_password = payload.new_password

    print(f"🔎 Requête reçue pour set-password avec identifiant: {identifier}, code: {code}")

    result = await db.execute(
        select(User).where((User.email == identifier) | (User.telephone == identifier))
    )
    user = result.scalars().first()
    print(f"➡️ Utilisateur trouvé: {user.email if user else 'aucun'}")

    if not user:
        print("❌ Aucun utilisateur trouvé")
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    reset_code = await db.execute(
        select(PasswordResetCode).where(
            PasswordResetCode.user_id == user.id,
            PasswordResetCode.code == code,
            PasswordResetCode.expires_at > datetime.utcnow()
        )
    )
    reset_code = reset_code.scalars().first()
    print(f"➡️ Code trouvé en base: {reset_code.code if reset_code else 'aucun'}")

    if not reset_code:
        print("❌ Code invalide ou expiré")
        raise HTTPException(status_code=400, detail="Code invalide ou expiré")

    print(f"🛠 Mise à jour du mot de passe pour {user.email}")
    user.password = hash_password(new_password)  
    await db.commit()
    await db.refresh(user)

    print(f"✅ Mot de passe mis à jour pour {user.email}")
    return {"status": "success", "message": "Mot de passe mis à jour avec succès"}


@router.post("/login")
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User).where((User.email == payload.identifier) | (User.telephone == payload.identifier))
    )
    user = result.scalars().first()

    if not user or not verify_password(payload.password, user.password):
        return {"status": "error", "message": "Email ou mot de passe incorrect"}

    access_token = create_access_token(data={"sub": user.email})

    result = await db.execute(
        select(UserSession).where(
            (UserSession.user_id == user.id) &
            (UserSession.device_type == payload.device_type)
        )
    )
    existing_device = result.scalars().first()

    if existing_device:
        if payload.device_type == "mobile":
            return {
                "status": "error",
                "message": "Ce compte est déjà connecté sur un téléphone"
            }

        elif payload.device_type == "pc":
            return {
                "status": "error",
                "message": "Ce compte est déjà connecté sur un ordinateur"
            }
        else:
            existing_device.token = access_token
            existing_device.is_active = True
            await db.commit()
    else:
        new_session = UserSession(
            user_id=user.id,
            token=access_token,
            device_id=payload.device_id,
            device_type=payload.device_type,
            is_active=True
        )
        db.add(new_session)
        await db.commit()
        await db.refresh(new_session)

    return {
        "status": "success",
        "message": "Connexion réussie",
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "nom": user.nom,
            "prenom": user.prenom,
            "email": user.email,
            "telephone": user.telephone,
            "pays": user.pays,
            "profession": user.profession,
            "role": user.role,
        },
    }

@router.post("/logout")
async def logout(
    payload: LogoutRequest | None = None,
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
):
    # 🔹 Identifier l'utilisateur via le token
    result = await db.execute(select(UserSession).where(UserSession.token == token))
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="Session introuvable")

    user_id = session.user_id

    

    if payload and payload.device_type:
        print("Device type reçu:", payload.device_type)
        # 🔹 Déconnexion ciblée (supprimer la session pour un device précis)
        result = await db.execute(
            select(UserSession).where(
                (UserSession.user_id == user_id) &
                (UserSession.device_type == payload.device_type)
            )
        )
        target_session = result.scalars().first()
        if not target_session:
            raise HTTPException(
                status_code=404,
                detail=f"Aucune session {payload.device_type} trouvée pour l'utilisateur {user_id}"
            )
        await db.delete(target_session)
        await db.commit()
        return {"status": "success", "message": f"Déconnecté sur {payload.device_type}"}
    else:
        # 🔹 Déconnexion globale (supprimer toutes les sessions de l'utilisateur)
        await db.execute(
            delete(UserSession).where(UserSession.user_id == user_id)
        )
        await db.commit()
        return {"status": "success", "message": "Déconnecté partout"}


@router.get("/me")
async def me(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    email = verify_token(token)
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    return {
        "id": user.id,
        "nom": user.nom,
        "prenom": user.prenom,
        "email": user.email,
        "telephone": user.telephone,
        "pays": user.pays,
        "profession": user.profession,
    }

@router.get("/admin/users", response_model=list[UserStatusResponse])
async def get_users_status(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User, UserSession).join(UserSession, User.id == UserSession.user_id, isouter=True)
    )
    rows = result.all()

    users_status = []
    for user, session in rows:
        users_status.append(UserStatusResponse(
            id=user.id,
            username=user.email,   # 🔹 remplacer par le champ réel
            connected=session.is_active if session else False,
            device_type=session.device_type if session else None
        ))

    return users_status