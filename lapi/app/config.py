"""Configuration : variables d'environnement (ou fichier .env), avec des valeurs
par défaut qui permettent de lancer le serveur sans rien configurer."""
import os
import secrets
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

DATA_DIR = Path(os.getenv("DATA_DIR", str(ROOT / "data"))).resolve()
UPLOAD_DIR = DATA_DIR / "uploads"
PDF_DIR = UPLOAD_DIR / "pdfs"        # jamais exposé directement : téléchargement authentifié
COVER_DIR = UPLOAD_DIR / "covers"    # servi en statique sous /covers

for _d in (DATA_DIR, PDF_DIR, COVER_DIR):
    _d.mkdir(parents=True, exist_ok=True)

DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite+aiosqlite:///{DATA_DIR / 'yaarexbook.db'}")


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

ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "").strip().lower()
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")

SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
MAIL_FROM = os.getenv("MAIL_FROM", "Yaarexbook <no-reply@yaarexbook.local>")

MAX_PDF_BYTES = 50 * 1024 * 1024
MAX_COVER_BYTES = 5 * 1024 * 1024
RESET_CODE_MINUTES = 15
RESET_CODE_MAX_ATTEMPTS = 5
