from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
from app.database import Base

import os
from sqlalchemy import create_engine

# Importer ton Base centralisé
from app.database import Base  
# Importer les modèles pour qu’ils soient enregistrés
from app.models.user import User
from app.models.user_session import UserSession
from app.models.document import Document
from app.models.bibliotheque import Bibliotheque
from app.models.transaction import Transaction, Wallet


# Charger la variable d'environnement
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not set")

# Alembic Config
config = context.config

# Injecter l'URL dans la config Alembic
config.set_main_option("sqlalchemy.url", DATABASE_URL)


# Logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# C’est ici qu’Alembic trouve les métadonnées
target_metadata = Base.metadata

def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()