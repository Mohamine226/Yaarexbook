from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# 🔹 URL de connexion SQLite en mode async
#SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:///./users.db"

SQLALCHEMY_DATABASE_URL = "postgresql+asyncpg://mohamine:6414Gnam1@localhost:5432/daagabase"

# Création du moteur async
engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL, echo=True
)

# Création de la session async
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False
)

# Base des modèles
Base = declarative_base()

# Dépendance pour obtenir une session DB
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session