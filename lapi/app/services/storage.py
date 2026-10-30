"""Fichiers téléversés, gardés sur le disque du serveur."""
import uuid
from pathlib import Path

from fastapi import HTTPException

from app.config import COVER_DIR, PDF_DIR

# Signature des fichiers -> extension. On ne fait jamais confiance au nom ni au
# type MIME envoyés par le client.
_IMAGE_SIGNATURES = [
    (b"\x89PNG\r\n\x1a\n", ".png"),
    (b"\xff\xd8\xff", ".jpg"),
    (b"GIF87a", ".gif"),
    (b"GIF89a", ".gif"),
]


def _image_extension(data: bytes) -> str | None:
    for signature, ext in _IMAGE_SIGNATURES:
        if data.startswith(signature):
            return ext
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return None


def save_pdf(data: bytes) -> str:
    if not data.startswith(b"%PDF"):
        raise HTTPException(status_code=400, detail="Le fichier doit être un PDF valide")
    name = f"{uuid.uuid4().hex}.pdf"
    (PDF_DIR / name).write_bytes(data)
    return name


def save_cover(data: bytes) -> str:
    ext = _image_extension(data)
    if ext is None:
        raise HTTPException(status_code=400, detail="La couverture doit être une image (PNG, JPEG, GIF ou WebP)")
    name = f"{uuid.uuid4().hex}{ext}"
    (COVER_DIR / name).write_bytes(data)
    return name


def pdf_path(name: str) -> Path:
    return PDF_DIR / name


def delete_files(pdf_files: list[str] = (), cover_files: list[str] = ()) -> None:
    for folder, names in ((PDF_DIR, pdf_files), (COVER_DIR, cover_files)):
        for name in names:
            try:
                (folder / Path(name).name).unlink(missing_ok=True)
            except OSError as exc:
                print(f"Impossible de supprimer {name}: {exc}")
