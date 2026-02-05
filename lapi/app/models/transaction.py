from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base 

class Wallet(Base):
    __tablename__ = "wallets"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)  # ✅ clé étrangère
    solde = Column(Float, default=0.0)
    date_creation = Column(DateTime, default=datetime.utcnow)

    transactions = relationship("Transaction", back_populates="wallet")
    user = relationship("User", back_populates="wallet")



class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    wallet_id = Column(Integer, ForeignKey("wallets.id"), nullable=True)
    acheteur_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # ✅ nouvelle colonne
    type = Column(String(20), nullable=False)   # "paiement" ou "retrait"
    montant = Column(Float, nullable=False)
    document_id = Column(Integer, nullable=True)
    document_nom = Column(String(255), nullable=True)  # ✅ nom du document
    status = Column(String(20), default="success")
    reference = Column(String(100), nullable=True)
    date_transaction = Column(DateTime, default=datetime.utcnow)

    wallet = relationship("Wallet", back_populates="transactions")