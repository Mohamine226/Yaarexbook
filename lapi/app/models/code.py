from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class VerificationCode(Base):
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    code = Column(String, index=True)  # le code à 6 chiffres
    expires_at = Column(DateTime)      # date d’expiration

    # Relation avec User
    user = relationship("User", backref="verification_codes")