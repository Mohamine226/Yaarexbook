from sqlalchemy import Column, Integer, Text, DateTime, Boolean, func
from app.database import Base

class UserSession(Base):
    __tablename__ = "user_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    token = Column(Text, nullable=False)
    device_id = Column(Text)
    device_type = Column(Text, nullable=False)   # 🔹 Ajouté
    created_at = Column(DateTime, server_default=func.now())
    is_active = Column(Boolean, server_default="true")