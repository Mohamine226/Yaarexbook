from app.database import Base, engine
from app.models.user import User
from app.models.document import Document
from app.models.bibliotheque import Bibliotheque

# ✅ Recrée toutes les tables avec les colonnes actuelles
Base.metadata.create_all(bind=engine)