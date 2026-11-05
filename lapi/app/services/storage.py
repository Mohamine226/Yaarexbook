
"""Gestion des fichiers Yaarexbook avec Supabase Storage.

Un seul bucket privé :
    yaarexbook/

Deux dossiers :
    covers/    : couvertures
    documents/ : fichiers PDF

Les PDF restent accessibles uniquement via le backend authentifié.
Les couvertures sont affichées grâce à des URL signées temporaires.
"""

import uuid
from pathlib import Path

import httpx
from fastapi import HTTPException

from app.config import (
    BUCKET,
    COVER_PREFIX,
    PDF_PREFIX,
    SUPABASE_SERVICE_KEY,
    SUPABASE_URL,
)

_API = f"{SUPABASE_URL}/storage/v1"

_TIMEOUT = httpx.Timeout(120.0)

_AUTH = {
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "apikey": SUPABASE_SERVICE_KEY,
}


# --------------------------------------------------
# VÉRIFICATION DE LA CONFIGURATION
# --------------------------------------------------

def _check_config():
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=503,
            detail="La configuration Supabase Storage est incomplète.",
        )


# --------------------------------------------------
# SIGNATURE DES IMAGES
# --------------------------------------------------

_IMAGE_SIGNATURES = [
    (b"\x89PNG\r\n\x1a\n", ".png"),
    (b"\xff\xd8\xff", ".jpg"),
    (b"GIF87a", ".gif"),
    (b"GIF89a", ".gif"),
]

_IMAGE_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
}


def _image_extension(data: bytes) -> str | None:
    for signature, ext in _IMAGE_SIGNATURES:
        if data.startswith(signature):
            return ext

    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"

    return None


# --------------------------------------------------
# CHEMINS DES FICHIERS
# --------------------------------------------------

def _path(prefix: str, name: str) -> str:
    """Empêche l'utilisation de chemins fournis par le client."""
    safe_name = Path(name).name

    if not safe_name or safe_name in (".", ".."):
        raise HTTPException(
            status_code=400,
            detail="Nom de fichier invalide.",
        )

    return f"{prefix}/{safe_name}"


# --------------------------------------------------
# ENVOI DES FICHIERS
# --------------------------------------------------

async def _upload(path: str, data: bytes, content_type: str) -> None:
    _check_config()

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(
                f"{_API}/object/{BUCKET}/{path}",
                content=data,
                headers={
                    **_AUTH,
                    "Content-Type": content_type,
                    "x-upsert": "false",
                },
            )

    except httpx.HTTPError as exc:
        print(f"Supabase Storage inaccessible : {exc}")

        raise HTTPException(
            status_code=502,
            detail="Stockage indisponible, veuillez réessayer.",
        )

    if response.status_code >= 300:
        print(
            f"Erreur Supabase Storage ({response.status_code}) : "
            f"{response.text}"
        )

        raise HTTPException(
            status_code=502,
            detail="Échec de l'enregistrement du fichier.",
        )


# --------------------------------------------------
# ENREGISTRER UN PDF
# --------------------------------------------------

async def save_pdf(data: bytes) -> str:
    if not data.startswith(b"%PDF"):
        raise HTTPException(
            status_code=400,
            detail="Le fichier doit être un PDF valide.",
        )

    name = f"{uuid.uuid4().hex}.pdf"

    await _upload(
        _path(PDF_PREFIX, name),
        data,
        "application/pdf",
    )

    return name


# --------------------------------------------------
# ENREGISTRER UNE COUVERTURE
# --------------------------------------------------

async def save_cover(data: bytes) -> str:
    ext = _image_extension(data)

    if ext is None:
        raise HTTPException(
            status_code=400,
            detail="La couverture doit être une image PNG, JPEG, GIF ou WebP.",
        )

    name = f"{uuid.uuid4().hex}{ext}"

    await _upload(
        _path(COVER_PREFIX, name),
        data,
        _IMAGE_TYPES[ext],
    )

    return name


# --------------------------------------------------
# LIRE UN PDF PRIVÉ
# --------------------------------------------------

async def read_pdf(name: str) -> bytes:
    """Récupère un PDF depuis le bucket privé."""

    _check_config()

    path = _path(PDF_PREFIX, name)

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.get(
                f"{_API}/object/authenticated/{BUCKET}/{path}",
                headers=_AUTH,
            )

    except httpx.HTTPError as exc:
        print(f"Supabase Storage inaccessible : {exc}")

        raise HTTPException(
            status_code=502,
            detail="Stockage indisponible, veuillez réessayer.",
        )

    if response.status_code in (400, 404):
        raise HTTPException(
            status_code=404,
            detail="Document introuvable.",
        )

    if response.status_code >= 300:
        print(
            f"Erreur lecture PDF ({response.status_code}) : "
            f"{response.text}"
        )

        raise HTTPException(
            status_code=502,
            detail="Impossible de lire le document.",
        )

    return response.content


# --------------------------------------------------
# URL SIGNÉE POUR LES COUVERTURES
# --------------------------------------------------

async def cover_signed_url(name: str, expires_in: int = 3600) -> str:
    """Génère une URL temporaire pour afficher une couverture."""

    _check_config()

    path = _path(COVER_PREFIX, name)

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(
                f"{_API}/object/sign/{BUCKET}/{path}",
                json={"expiresIn": expires_in},
                headers=_AUTH,
            )

    except httpx.HTTPError as exc:
        print(f"Supabase Storage inaccessible : {exc}")

        raise HTTPException(
            status_code=502,
            detail="Stockage indisponible, veuillez réessayer.",
        )

    if response.status_code in (400, 404):
        raise HTTPException(
            status_code=404,
            detail="Couverture introuvable.",
        )

    if response.status_code >= 300:
        print(
            f"Erreur signature URL ({response.status_code}) : "
            f"{response.text}"
        )

        raise HTTPException(
            status_code=502,
            detail="Impossible de générer le lien de la couverture.",
        )

    signed_url = response.json().get("signedURL")

    if not signed_url:
        raise HTTPException(
            status_code=502,
            detail="Supabase n'a pas retourné de lien valide.",
        )

    if signed_url.startswith("http://") or signed_url.startswith("https://"):
        return signed_url

    return f"{SUPABASE_URL}/storage/v1{signed_url}"


# --------------------------------------------------
# SUPPRIMER DES FICHIERS
# --------------------------------------------------

async def delete_files(
    pdf_files: list[str] = (),
    cover_files: list[str] = (),
) -> None:
    """Supprime les PDF et couvertures du bucket."""

    _check_config()

    paths = (
        [_path(PDF_PREFIX, name) for name in pdf_files if name]
        + [_path(COVER_PREFIX, name) for name in cover_files if name]
    )

    if not paths:
        return

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.request(
                "DELETE",
                f"{_API}/object/{BUCKET}",
                json={"prefixes": paths},
                headers=_AUTH,
            )

    except httpx.HTTPError as exc:
        print(f"Impossible de supprimer les fichiers : {exc}")
        return

    if response.status_code >= 300:
        print(
            f"Suppression Supabase refusée ({response.status_code}) : "
            f"{response.text}"
        )
