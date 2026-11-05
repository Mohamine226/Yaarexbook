
"""Connexion à PostgreSQL Supabase avec SQLAlchemy asynchrone."""

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool

from app.config import DATABASE_URL


# --------------------------------------------------
# BASE DES MODÈLES
# --------------------------------------------------

class Base(DeclarativeBase):
    pass


# --------------------------------------------------
# CONNEXION POSTGRESQL SUPABASE
# --------------------------------------------------

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    poolclass=NullPool,
    connect_args={
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0,
    },
)


# --------------------------------------------------
# GESTION DES SESSIONS
# --------------------------------------------------

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


# --------------------------------------------------
# DÉPENDANCE FASTAPI
# --------------------------------------------------

async def get_db():
    async with SessionLocal() as session:
        yield session


# --------------------------------------------------
# FERMETURE DU MOTEUR
# --------------------------------------------------

async def close_database():
    await engine.dispose()
