from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import DATABASE_URL


class Base(DeclarativeBase):
    pass


engine = create_async_engine(DATABASE_URL, echo=False)


@event.listens_for(engine.sync_engine, "connect")
def _enable_foreign_keys(dbapi_connection, _record):
    """SQLite n'applique pas les clés étrangères (ni ON DELETE CASCADE) par défaut."""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


SessionLocal = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)


async def get_db():
    async with SessionLocal() as session:
        yield session


async def create_tables() -> None:
    """Crée toutes les tables si elles n'existent pas (aucune migration)."""
    from app import models  # noqa: F401  (enregistre les modèles)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
