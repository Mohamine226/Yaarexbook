from datetime import datetime, timezone
from typing import Annotated, Generic, Optional, TypeVar

from pydantic import AfterValidator, BaseModel, ConfigDict, EmailStr, Field

T = TypeVar("T")


def _as_utc(value: datetime | None) -> datetime | None:
    """La base stocke des dates UTC sans fuseau : on les renvoie avec un « Z »
    pour que l'application les convertisse correctement à l'heure locale."""
    if value is not None and value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


UtcDateTime = Annotated[datetime, AfterValidator(_as_utc)]


class Page(BaseModel, Generic[T]):
    """Liste paginée. `next_cursor` est à renvoyer tel quel pour obtenir la page
    suivante ; null = fin de la liste."""

    items: list[T]
    next_cursor: Optional[int] = None


# ----------------------------------------------------------------- entrées
class RegisterIn(BaseModel):
    nom: str = Field(min_length=1, max_length=100)
    prenom: str = Field(min_length=1, max_length=100)
    email: EmailStr
    telephone: Optional[str] = Field(default=None, max_length=30)
    pays: Optional[str] = Field(default=None, max_length=100)
    profession: Optional[str] = Field(default=None, max_length=150)
    password: str = Field(min_length=8, max_length=128)
    code: str = Field(min_length=1, max_length=20)  # à ajouter dans RegisterIn


class SendCodeIn(BaseModel):
    email: EmailStr


class LoginIn(BaseModel):
    identifier: str = Field(min_length=1, max_length=255)  # email ou téléphone
    password: str = Field(min_length=1, max_length=128)
    device_id: str = Field(default="", max_length=100)
    device_name: str = Field(default="", max_length=150)


class ProfileUpdate(BaseModel):
    nom: Optional[str] = Field(default=None, min_length=1, max_length=100)
    prenom: Optional[str] = Field(default=None, min_length=1, max_length=100)
    telephone: Optional[str] = Field(default=None, max_length=30)
    pays: Optional[str] = Field(default=None, max_length=100)
    profession: Optional[str] = Field(default=None, max_length=150)


class ChangePasswordIn(BaseModel):
    old_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class ForgotPasswordIn(BaseModel):
    identifier: str = Field(min_length=1, max_length=255)


class ResetPasswordIn(BaseModel):
    identifier: str = Field(min_length=1, max_length=255)
    code: str = Field(min_length=1, max_length=20)
    new_password: str = Field(min_length=8, max_length=128)


class DeleteAccountIn(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class CommentIn(BaseModel):
    contenu: str = Field(min_length=1, max_length=1000)


class RoleIn(BaseModel):
    role: str = Field(pattern="^(membre|admin)$")


# ----------------------------------------------------------------- sorties
class UserOut(BaseModel):
    """Compte complet : visible par son propriétaire et par les administrateurs."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nom: str
    prenom: str
    email: str
    telephone: Optional[str] = None
    pays: Optional[str] = None
    profession: Optional[str] = None
    role: str
    created_at: Optional[UtcDateTime] = None


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class PublicUser(BaseModel):
    """Profil public : jamais d'email, de téléphone ni de rôle."""

    id: int
    nom: str
    prenom: str
    pays: Optional[str] = None
    profession: Optional[str] = None
    created_at: Optional[UtcDateTime] = None
    nb_documents: int = 0
    nb_abonnes: int = 0
    nb_abonnements: int = 0
    is_following: bool = False
    is_me: bool = False


class DeviceOut(BaseModel):
    id: int
    device_name: str
    created_at: Optional[UtcDateTime] = None
    last_seen: Optional[UtcDateTime] = None
    current: bool = False


class DocumentOut(BaseModel):
    id: int
    titre: str
    description: str = ""
    categorie: str
    langue: str
    domaine: str = ""
    couverture_url: str          # chemin relatif, ex. /covers/abc.jpg
    auteur_id: int
    auteur_nom: str = ""
    nb_likes: int = 0
    nb_commentaires: int = 0
    nb_ajouts: int = 0           # nombre de bibliothèques qui contiennent le document
    liked: bool = False          # le lecteur connecté a-t-il aimé ce document ?
    dans_bibliotheque: bool = False
    is_disabled: bool = False
    created_at: Optional[UtcDateTime] = None
    auteur_suivi: Optional[bool] = None  # None = c'est mon propre document


class CommentOut(BaseModel):
    id: int
    document_id: int
    user_id: int
    auteur_nom: str
    contenu: str
    created_at: Optional[UtcDateTime] = None


class LikeOut(BaseModel):
    liked: bool
    nb_likes: int


class FollowOut(BaseModel):
    is_following: bool
    nb_abonnes: int


class StatsOut(BaseModel):
    total_utilisateurs: int
    total_documents: int
    documents_desactives: int
    total_likes: int
    total_commentaires: int
    total_abonnements: int
    ajouts_bibliotheque: int
    connexions_actives: int
    nouveaux_documents_mois: int
    nouveaux_documents_annee: int


class Message(BaseModel):
    message: str
