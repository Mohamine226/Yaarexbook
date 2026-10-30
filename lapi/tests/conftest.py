import os
import tempfile

# Données de test isolées : à définir AVANT d'importer l'application.
_tmp = tempfile.mkdtemp(prefix="yaarexbook-test-")
os.environ["DATA_DIR"] = _tmp
os.environ["ADMIN_EMAIL"] = "admin@test.local"
os.environ["ADMIN_PASSWORD"] = "AdminPass123"
os.environ["SECRET_KEY"] = "test-secret-key-test-secret-key-0123456789"
os.environ.pop("DATABASE_URL", None)
os.environ.pop("SMTP_HOST", None)

import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402

from app.config import COVER_DIR, PDF_DIR  # noqa: E402
from app.database import Base, engine  # noqa: E402
from app.main import app, seed_admin  # noqa: E402

PDF = b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


@pytest_asyncio.fixture
async def client():
    for d in (PDF_DIR, COVER_DIR):
        for f in d.iterdir():
            f.unlink()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    await seed_admin()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    await engine.dispose()


async def register(c, email, password="Motdepasse1", nom="Doe", prenom="Jane", **extra):
    r = await c.post("/auth/register", json={"nom": nom, "prenom": prenom, "email": email, "password": password, **extra})
    assert r.status_code == 201, r.text
    return r.json()


async def login(c, email, password="Motdepasse1", device="dev-1"):
    r = await c.post(
        "/auth/login",
        json={"identifier": email, "password": password, "device_id": device, "device_name": "Test"},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"], r.json()


def H(token):
    return {"Authorization": f"Bearer {token}"}


async def new_user(c, email, device="dev-1"):
    await register(c, email)
    token, _ = await login(c, email, device=device)
    return token


async def publish(c, token, titre="Mon doc", categorie="Science", **extra):
    data = {"titre": titre, "description": "desc", "categorie": categorie, "langue": "Français", "domaine": "Maths", **extra}
    files = {"pdf": ("a.pdf", PDF, "application/pdf"), "couverture": ("c.png", PNG, "image/png")}
    return await c.post("/documents", data=data, files=files, headers=H(token))
