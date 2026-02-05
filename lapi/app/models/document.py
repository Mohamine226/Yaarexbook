from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from app.database import Base
from datetime import datetime

class Document(Base):
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    titre = Column(String, nullable=False)
    description = Column(String, nullable=True)
    prix = Column(Float, nullable=False)
    categorie = Column(String, nullable=False)
    langue = Column(String, nullable=False)
    domaine = Column(String, nullable=True)
    pdf_path = Column(String, nullable=False)
    couverture_path = Column(String, nullable=False)
    achats = Column(Integer, default=0)  # ✅ compteur d’achats

    vendeur_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vendeur = relationship("User", back_populates="documents")
    date_publication = Column(DateTime, default=datetime.utcnow)  # ✅ fonctionne maintenant
    is_deleted = Column(Boolean, default=False)  # ✅ soft delete
    user_id = Column(Integer, ForeignKey("users.id"))  # nouveau champ

    # Relations (optionnel)
    vendeur = relationship("User", foreign_keys=[vendeur_id], back_populates="documents")
    user = relationship("User", foreign_keys=[user_id], back_populates="user_documents")





