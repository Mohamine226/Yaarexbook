from sqlalchemy import Column, Integer, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base

class Bibliotheque(Base):
    __tablename__ = "bibliotheque"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    document_id = Column(Integer, ForeignKey("documents.id"), nullable=False)

    # 🔹 Date d’ajout du document dans la bibliothèque
    date_ajout = Column(DateTime(timezone=True), server_default=func.now())