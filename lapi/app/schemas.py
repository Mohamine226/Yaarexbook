from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional
from app.models import Document



class ResendCodeRequest(BaseModel):
    email: str


class VerifyRequest(BaseModel):
    email: str   # l'identifiant de l'utilisateur (email ou téléphone)
    code: str    # le code de vérification à 6 chiffres

class LogoutRequest(BaseModel):
    user_id: int | None = None   # optionnel si on utilise le token
    device_type: str | None = None  # "mobile" ou "pc", optionnel

class UserStatusResponse(BaseModel):
    id: int
    username: str
    connected: bool
    device_type: str | None

class RoleUpdate(BaseModel):
    new_role: str
    password: str   # 🔹 ajoute le champ mot de passe
    
class ChangePasswordRequest(BaseModel):
    user_id: str
    old_password: str
    new_password: str

class ProfileUpdate(BaseModel):
    email: EmailStr
    pays: str
    profession: str

class ForgotPasswordRequest(BaseModel):
    identifier: str

class PasswordUpdate(BaseModel):
    identifier: str   # email ou téléphone
    code: str
    new_password: str

class VerifyResetCodeRequest(BaseModel):
    identifier: str   # email ou téléphone
    code: str         # code de vérification


# 🔹 Schéma pour l'inscription
class UserCreate(BaseModel):
    nom: str
    prenom: str
    email: EmailStr
    telephone: str
    pays: str
    profession: str
    password: str

class UserCreateAdmin(BaseModel):
    nom: str
    prenom: str
    email: EmailStr
    telephone: str
    pays: str
    profession: str
    password: str
    role: str

# 🔹 Schéma pour la réponse utilisateur (sans mot de passe)
class UserResponse(BaseModel):
    id: int
    nom: str
    prenom: str
    email: EmailStr
    telephone: str
    pays: str
    profession: str
    date_publication: Optional[datetime] = None  #  ajouté



    class Config:
        from_attributes = True # permet de convertir un objet SQLAlchemy en JSON

# 🔹 Schéma pour la connexion
class LoginRequest(BaseModel):
    identifier: str
    password: str
    device_id: str    # identifiant unique de l’appareil
    device_type: str # "mobile" ou "pc"



class DocumentCreate(BaseModel):
    titre: str
    description: str
    prix: int
    categorie: str
    langue: str
    domaine: str
    pdf_path: str
    couverture_path: str

class DocumentResponse(BaseModel):
    id: int
    titre: str
    description: str
    prix: int
    categorie: str
    langue: str
    domaine: str
    pdfUrl: Optional[str] = None
    imageUrl: Optional[str] = None
    vendeur_id: int
    achats: int
    date_publication: Optional[datetime] = None

    class Config:
        from_attributes = True

class Documentbiblio(BaseModel):
    id: int
    titre: str
    description: str
    prix: int
    categorie: str
    langue: str
    domaine: str
    pdfUrl: Optional[str] = None
    imageUrl: Optional[str] = None
    vendeur_id: int
    achats: int
    date_publication: Optional[datetime] = None

    class Config:
        from_attributes = True

    @classmethod
    def from_orm_with_urls(cls, doc: "Document"):
        return cls(
            id=doc.id,
            titre=doc.titre,
            description=doc.description,
            prix=doc.prix,
            categorie=doc.categorie,
            langue=doc.langue,
            domaine=doc.domaine,
            pdfUrl=doc.pdf_path,          # ⚠️ déjà une URL complète
            imageUrl=doc.couverture_path, # ⚠️ déjà une URL complète
            vendeur_id=doc.vendeur_id,
            achats=doc.achats,
            date_publication=doc.date_publication,
        )



# Wallet et Transaction

class WalletBase(BaseModel):
    vendeur_id: int
    solde: int = 0

class WalletCreate(WalletBase):
    pass

class Wallet(WalletBase):
    id: int
    date_creation: datetime

    class Config:
        from_attributes = True

class TransactionBase(BaseModel):
    wallet_id: int | None = None
    acheteur_id: Optional[int] 
    type: str   # "paiement" ou "retrait"
    montant: int
    document_id: int | None = None
    document_nom: str | None = None
    status: str = "success"
    reference: str | None = None

class TransactionCreate(TransactionBase):
    pass


class AchatCreate(BaseModel):
    montant: int
    document_id: int
    document_nom: str
    reference: str
    acheteur_id: int

class Transaction(TransactionBase):
    id: int
    date_transaction: datetime

    class Config:
        from_attributes = True

class WalletWithTransactions(Wallet):
    transactions: list[Transaction] = []

class RetraitCreate(BaseModel):
    wallet_id: int
    type: str
    montant: int
    status: str
    reference: str

class RetraitResponse(BaseModel):
    id: int
    wallet_id: int
    type: str
    montant: int
    status: str
    reference: Optional[str]
    date_transaction: datetime
    message: str
    solde_restant: int
