
"""Configuration : variables d'environnement (ou fichier .env)."""

import os
import secrets
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

# Répertoires locaux conservés pour compatibilité
DATA_DIR = Path(os.getenv("DATA_DIR", str(ROOT / "data"))).resolve()
UPLOAD_DIR = DATA_DIR / "uploads"
PDF_DIR = UPLOAD_DIR / "pdfs"
COVER_DIR = UPLOAD_DIR / "covers"

for _d in (DATA_DIR, PDF_DIR, COVER_DIR):
    _d.mkdir(parents=True, exist_ok=True)


# --------------------------------------------------
# BASE DE DONNÉES POSTGRESQL SUPABASE
# --------------------------------------------------

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

if not DATABASE_URL:
    raise RuntimeError(
        "DATABASE_URL manquant : configure PostgreSQL Supabase dans .env"
    )

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace(
        "postgres://",
        "postgresql+asyncpg://",
        1,
    )
elif DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace(
        "postgresql://",
        "postgresql+asyncpg://",
        1,
    )


# --------------------------------------------------
# SUPABASE STORAGE
# --------------------------------------------------

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "").strip()

BUCKET = os.getenv("SUPABASE_BUCKET", "yaarexbook").strip()

COVER_PREFIX = "covers"
PDF_PREFIX = "documents"


# --------------------------------------------------
# CLÉ SECRÈTE
# --------------------------------------------------

def _load_secret() -> str:
    env = os.getenv("SECRET_KEY")

    if env:
        return env

    path = DATA_DIR / "secret_key"

    if path.exists():
        return path.read_text().strip()

    key = secrets.token_urlsafe(48)
    path.write_text(key)

    try:
        path.chmod(0o600)
    except OSError:
        pass

    return key


SECRET_KEY = _load_secret()

TOKEN_DAYS = int(os.getenv("TOKEN_DAYS", "30"))


# --------------------------------------------------
# ADMINISTRATEUR
# --------------------------------------------------

ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "").strip().lower()
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")


# --------------------------------------------------
# EMAIL / SMTP
# --------------------------------------------------

SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")

MAIL_FROM = os.getenv(
    "MAIL_FROM",
    "Yaarexbook <no-reply@yaarexbook.local>",
)


# --------------------------------------------------
# LIMITES DES FICHIERS
# --------------------------------------------------

MAX_PDF_BYTES = 50 * 1024 * 1024
MAX_COVER_BYTES = 5 * 1024 * 1024

RESET_CODE_MINUTES = 15
RESET_CODE_MAX_ATTEMPTS = 5


# --------------------------------------------------
# BREVO
# --------------------------------------------------

BREVO_API_KEY = os.getenv("BREVO_API_KEY", "")
MAIL_FROM_EMAIL = os.getenv("MAIL_FROM_EMAIL", "")
MAIL_FROM_NAME = os.getenv("MAIL_FROM_NAME", "Yaarexbook")
