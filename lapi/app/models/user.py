from sqlalchemy import Column, Integer, String, DateTime, func, Boolean
from sqlalchemy.orm import relationship
from app.database import Base
from datetime import datetime


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    nom = Column(String, nullable=False)
    prenom = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    telephone = Column(String, unique=True, index=True, nullable=True)
    pays = Column(String, nullable=True)
    profession = Column(String, nullable=True)
    password = Column(String(255), nullable=False)
    role = Column(String, default="acheteur")

    ventes = Column(Integer, default=0)  #  compteur des ventes réalisées
    date_publication = Column(DateTime, server_default=func.now())


    # 🔹 Relation avec Document
    documents = relationship("Document", back_populates="vendeur")
     # 🔹 Ajoute cette colonne
    is_verified = Column(Boolean, default=False)
    reset_codes = relationship("PasswordResetCode", back_populates="user")
    wallet = relationship("Wallet", back_populates="user", uselist=False)

     # Relation avec Document via vendeur_id
    documents = relationship(
        "Document",
        back_populates="vendeur",
        foreign_keys="Document.vendeur_id"
    )

    # Relation avec Document via user_id (si tu veux aussi suivre ça)
    user_documents = relationship(
        "Document",
        back_populates="user",
        foreign_keys="Document.user_id"
    )



