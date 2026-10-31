import hashlib
import hmac
import secrets
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import RESET_CODE_MAX_ATTEMPTS, RESET_CODE_MINUTES, SECRET_KEY
from app.database import get_db
from app.models import DeviceSession, Document, PasswordResetCode, User,EmailVerification , utcnow
from app.schemas import (
    ChangePasswordIn,
    DeleteAccountIn,
    DeviceOut,
    ForgotPasswordIn,
    LoginIn,
    LoginOut,
    Message,
    ProfileUpdate,
    RegisterIn,
    ResetPasswordIn,
    UserOut,
    SendCodeIn,
)
from app.security import Auth, create_token, current_auth, current_user, hash_password, verify_password
from app.services import storage
from app.services.mailer import send_reset_code, send_verification_code

router = APIRouter(prefix="/auth", tags=["auth"])


def _clean(value: str | None) -> str | None:
    value = (value or "").strip()
    return value or None


async def find_user(db: AsyncSession, identifier: str) -> User | None:
    """Retrouve un compte par email (insensible à la casse) ou par téléphone."""
    identifier = identifier.strip()
    return (
        await db.execute(
            select(User).where((User.email == identifier.lower()) | (User.telephone == identifier))
        )
    ).scalars().first()


# ------------------------------------------------------------------ inscription / connexion
def _email_code_hash(email: str, code: str) -> str:
    return hashlib.sha256(f"{SECRET_KEY}:register:{email}:{code}".encode()).hexdigest()


@router.post("/register-code", response_model=Message)
async def register_code(payload: SendCodeIn, db: AsyncSession = Depends(get_db)):
    """Étape 1 de l'inscription : envoie un code de confirmation à l'email."""
    email = payload.email.lower()
    if (await db.execute(select(User).where(User.email == email))).scalars().first():
        raise HTTPException(status_code=409, detail="Cet email est déjà utilisé")

    ok = Message(message="Un code de confirmation vient d'être envoyé par email")
    last = (await db.execute(select(EmailVerification).where(EmailVerification.email == email))).scalars().first()
    if last and utcnow() - last.created_at < timedelta(seconds=60):
        return ok

    code = f"{secrets.randbelow(1_000_000):06d}"
    await db.execute(delete(EmailVerification).where(EmailVerification.email == email))
    db.add(
        EmailVerification(
            email=email,
            code_hash=_email_code_hash(email, code),
            expires_at=utcnow() + timedelta(minutes=RESET_CODE_MINUTES),
        )
    )
    await db.commit()
    await send_verification_code(email, code, RESET_CODE_MINUTES)
    return ok


@router.post("/register", response_model=UserOut, status_code=201)
async def register(payload: RegisterIn, db: AsyncSession = Depends(get_db)):
    email = payload.email.lower()
    telephone = _clean(payload.telephone)

    if (await db.execute(select(User).where(User.email == email))).scalars().first():
        raise HTTPException(status_code=409, detail="Cet email est déjà utilisé")
    if telephone and (await db.execute(select(User).where(User.telephone == telephone))).scalars().first():
        raise HTTPException(status_code=409, detail="Ce numéro de téléphone est déjà utilisé")

    invalid = HTTPException(status_code=400, detail="Code invalide ou expiré")
    entry = (await db.execute(select(EmailVerification).where(EmailVerification.email == email))).scalars().first()
    if entry is None or entry.expires_at < utcnow():
        raise invalid
    if not hmac.compare_digest(entry.code_hash, _email_code_hash(email, payload.code.strip())):
        entry.attempts += 1
        if entry.attempts >= RESET_CODE_MAX_ATTEMPTS:
            await db.delete(entry)
        await db.commit()
        raise invalid

    user = User(
        nom=payload.nom.strip(),
        prenom=payload.prenom.strip(),
        email=email,
        telephone=telephone,
        pays=_clean(payload.pays),
        profession=_clean(payload.profession),
        password_hash=await hash_password(payload.password),
        role="membre",
    )
    db.add(user)
    await db.delete(entry)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Email ou téléphone déjà utilisé")
    await db.refresh(user)
    return user


@router.post("/login", response_model=LoginOut)
async def login(payload: LoginIn, db: AsyncSession = Depends(get_db)):
    user = await find_user(db, payload.identifier)
    if not await verify_password(payload.password, user.password_hash if user else None) or user is None:
        raise HTTPException(status_code=401, detail="Identifiant ou mot de passe incorrect")

    # Chaque appareil a sa propre session ; reconnecter le même appareil réutilise la sienne.
    session = None
    if payload.device_id:
        session = (
            await db.execute(
                select(DeviceSession).where(
                    DeviceSession.user_id == user.id, DeviceSession.device_id == payload.device_id
                )
            )
        ).scalars().first()
    if session is None:
        session = DeviceSession(user_id=user.id, device_id=payload.device_id or secrets.token_hex(8))
        db.add(session)
    session.device_name = payload.device_name.strip() or session.device_name or "Appareil inconnu"
    session.last_seen = utcnow()
    await db.commit()
    await db.refresh(session)

    return LoginOut(access_token=create_token(user.id, session.id), user=user)


@router.post("/logout", response_model=Message)
async def logout(auth: Auth = Depends(current_auth), db: AsyncSession = Depends(get_db)):
    """Déconnecte uniquement l'appareil qui fait la demande."""
    await db.execute(delete(DeviceSession).where(DeviceSession.id == auth.session.id))
    await db.commit()
    return Message(message="Déconnecté")


# ------------------------------------------------------------------ mon compte
@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(current_user)):
    return user


@router.put("/me", response_model=UserOut)
async def update_me(payload: ProfileUpdate, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    data = payload.model_dump(exclude_unset=True)

    if "telephone" in data:
        telephone = _clean(data["telephone"])
        if telephone and telephone != user.telephone:
            taken = (
                await db.execute(select(User).where(User.telephone == telephone, User.id != user.id))
            ).scalars().first()
            if taken:
                raise HTTPException(status_code=409, detail="Ce numéro de téléphone est déjà utilisé")
        user.telephone = telephone
    for field in ("nom", "prenom"):
        if data.get(field):
            setattr(user, field, data[field].strip())
    for field in ("pays", "profession"):
        if field in data:
            setattr(user, field, _clean(data[field]))

    await db.commit()
    await db.refresh(user)
    return user


@router.post("/change-password", response_model=Message)
async def change_password(
    payload: ChangePasswordIn,
    auth: Auth = Depends(current_auth),
    db: AsyncSession = Depends(get_db),
):
    if not await verify_password(payload.old_password, auth.user.password_hash):
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect")

    auth.user.password_hash = await hash_password(payload.new_password)
    # Par sécurité, les autres appareils doivent se reconnecter avec le nouveau mot de passe.
    await db.execute(
        delete(DeviceSession).where(DeviceSession.user_id == auth.user.id, DeviceSession.id != auth.session.id)
    )
    await db.commit()
    return Message(message="Mot de passe changé")


@router.post("/delete-account", response_model=Message)
async def delete_account(
    payload: DeleteAccountIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)
):
    if not await verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Mot de passe incorrect")

    docs = (await db.execute(select(Document).where(Document.auteur_id == user.id))).scalars().all()
    pdfs, covers = [d.pdf_file for d in docs], [d.cover_file for d in docs]

    await db.delete(user)  # les tables liées sont nettoyées par ON DELETE CASCADE
    await db.commit()
    storage.delete_files(pdfs, covers)
    return Message(message="Compte supprimé")


# ------------------------------------------------------------------ appareils connectés
@router.get("/sessions", response_model=list[DeviceOut])
async def list_sessions(auth: Auth = Depends(current_auth), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.execute(
            select(DeviceSession)
            .where(DeviceSession.user_id == auth.user.id)
            .order_by(DeviceSession.last_seen.desc())
        )
    ).scalars().all()
    return [
        DeviceOut(
            id=s.id,
            device_name=s.device_name,
            created_at=s.created_at,
            last_seen=s.last_seen,
            current=s.id == auth.session.id,
        )
        for s in rows
    ]


@router.delete("/sessions/{session_id}", response_model=Message)
async def revoke_session(session_id: int, auth: Auth = Depends(current_auth), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        delete(DeviceSession).where(DeviceSession.id == session_id, DeviceSession.user_id == auth.user.id)
    )
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Appareil introuvable")
    return Message(message="Appareil déconnecté")


@router.delete("/sessions", response_model=Message)
async def revoke_other_sessions(auth: Auth = Depends(current_auth), db: AsyncSession = Depends(get_db)):
    """Déconnecte tous les autres appareils (celui-ci reste connecté)."""
    await db.execute(
        delete(DeviceSession).where(DeviceSession.user_id == auth.user.id, DeviceSession.id != auth.session.id)
    )
    await db.commit()
    return Message(message="Les autres appareils ont été déconnectés")


# ------------------------------------------------------------------ mot de passe oublié
def _hash_code(user_id: int, code: str) -> str:
    return hashlib.sha256(f"{SECRET_KEY}:{user_id}:{code}".encode()).hexdigest()


@router.post("/forgot-password", response_model=Message)
async def forgot_password(payload: ForgotPasswordIn, db: AsyncSession = Depends(get_db)):
    ok = Message(message="Un code de vérification vient d'être envoyé par email")

    user = await find_user(db, payload.identifier)
    if user is None:
        raise HTTPException(status_code=404, detail="Aucun compte n'existe avec cet email")

    last = (
        await db.execute(
            select(PasswordResetCode)
            .where(PasswordResetCode.user_id == user.id)
            .order_by(PasswordResetCode.id.desc())
        )
    ).scalars().first()
    if last and utcnow() - last.created_at < timedelta(seconds=60):
        return ok  # au plus un code par minute : le code déjà envoyé reste valable

    code = f"{secrets.randbelow(1_000_000):06d}"
    await db.execute(delete(PasswordResetCode).where(PasswordResetCode.user_id == user.id))
    db.add(
        PasswordResetCode(
            user_id=user.id,
            code_hash=_hash_code(user.id, code),
            expires_at=utcnow() + timedelta(minutes=RESET_CODE_MINUTES),
        )
    )
    await db.commit()
    await send_reset_code(user.email, code, RESET_CODE_MINUTES)
    return ok


@router.post("/reset-password", response_model=Message)
async def reset_password(payload: ResetPasswordIn, db: AsyncSession = Depends(get_db)):
    invalid = HTTPException(status_code=400, detail="Code invalide ou expiré")

    user = await find_user(db, payload.identifier)
    if user is None:
        raise invalid
    entry = (
        await db.execute(
            select(PasswordResetCode)
            .where(PasswordResetCode.user_id == user.id)
            .order_by(PasswordResetCode.id.desc())
        )
    ).scalars().first()
    if entry is None or entry.expires_at < utcnow():
        raise invalid

    if not hmac.compare_digest(entry.code_hash, _hash_code(user.id, payload.code.strip())):
        entry.attempts += 1
        if entry.attempts >= RESET_CODE_MAX_ATTEMPTS:
            await db.delete(entry)  # trop d'essais : il faut redemander un code
        await db.commit()
        raise invalid

    user.password_hash = await hash_password(payload.new_password)
    await db.execute(delete(PasswordResetCode).where(PasswordResetCode.user_id == user.id))
    await db.execute(delete(DeviceSession).where(DeviceSession.user_id == user.id))  # reconnexion partout
    await db.commit()
    return Message(message="Mot de passe réinitialisé, vous pouvez vous connecter")
