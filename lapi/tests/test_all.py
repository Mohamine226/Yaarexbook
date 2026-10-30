import os

import pytest

from app.config import COVER_DIR, PDF_DIR
from tests.conftest import H, PDF, PNG, login, new_user, publish, register


# ------------------------------------------------------------------ auth
async def test_register_forces_member_role(client):
    u = await register(client, "a@x.com", role="admin")
    assert u["role"] == "membre"


async def test_register_duplicate_email(client):
    await register(client, "a@x.com")
    r = await client.post("/auth/register", json={"nom": "A", "prenom": "B", "email": "a@x.com", "password": "Motdepasse1"})
    assert r.status_code == 409


async def test_login_wrong_password(client):
    await register(client, "a@x.com")
    r = await client.post("/auth/login", json={"identifier": "a@x.com", "password": "nope-nope", "device_id": "d"})
    assert r.status_code == 401


async def test_protected_requires_token(client):
    assert (await client.get("/documents")).status_code in (401, 403)


async def test_multi_device_same_account(client):
    await register(client, "a@x.com")
    t1, _ = await login(client, "a@x.com", device="phone")
    t2, _ = await login(client, "a@x.com", device="tablet")
    assert t1 != t2
    assert (await client.get("/auth/me", headers=H(t1))).status_code == 200
    assert (await client.get("/auth/me", headers=H(t2))).status_code == 200
    # Déconnexion d'un seul appareil : l'autre reste connecté.
    assert (await client.post("/auth/logout", headers=H(t1))).status_code == 200
    assert (await client.get("/auth/me", headers=H(t1))).status_code == 401
    assert (await client.get("/auth/me", headers=H(t2))).status_code == 200


async def test_relogin_same_device_reuses_session(client):
    await register(client, "a@x.com")
    t, _ = await login(client, "a@x.com", device="phone")
    await login(client, "a@x.com", device="phone")
    r = await client.get("/auth/sessions", headers=H(t))
    assert len(r.json()) == 1


async def test_list_and_revoke_devices(client):
    await register(client, "a@x.com")
    t1, _ = await login(client, "a@x.com", device="phone")
    t2, _ = await login(client, "a@x.com", device="tablet")
    sessions = (await client.get("/auth/sessions", headers=H(t1))).json()
    assert len(sessions) == 2
    assert [s for s in sessions if s["current"]]
    other = [s for s in sessions if not s["current"]][0]
    assert (await client.delete(f"/auth/sessions/{other['id']}", headers=H(t1))).status_code == 200
    assert (await client.get("/auth/me", headers=H(t2))).status_code == 401
    assert (await client.get("/auth/me", headers=H(t1))).status_code == 200


async def test_revoke_other_sessions(client):
    await register(client, "a@x.com")
    t1, _ = await login(client, "a@x.com", device="a")
    t2, _ = await login(client, "a@x.com", device="b")
    assert (await client.delete("/auth/sessions", headers=H(t1))).status_code == 200
    assert (await client.get("/auth/me", headers=H(t2))).status_code == 401
    assert (await client.get("/auth/me", headers=H(t1))).status_code == 200


async def test_update_profile(client):
    t = await new_user(client, "a@x.com")
    r = await client.put("/auth/me", json={"nom": "Nouveau", "prenom": "Nom", "pays": "Mali", "profession": "Dev"}, headers=H(t))
    assert r.status_code == 200
    assert r.json()["nom"] == "Nouveau" and r.json()["pays"] == "Mali"


async def test_change_password_revokes_other_sessions(client):
    await register(client, "a@x.com")
    t1, _ = await login(client, "a@x.com", device="a")
    t2, _ = await login(client, "a@x.com", device="b")
    r = await client.post("/auth/change-password", json={"old_password": "Motdepasse1", "new_password": "Nouveau1234"}, headers=H(t1))
    assert r.status_code == 200, r.text
    assert (await client.get("/auth/me", headers=H(t2))).status_code == 401
    assert (await client.get("/auth/me", headers=H(t1))).status_code == 200
    await login(client, "a@x.com", password="Nouveau1234", device="c")


async def test_change_password_wrong_old(client):
    t = await new_user(client, "a@x.com")
    r = await client.post("/auth/change-password", json={"old_password": "faux-faux", "new_password": "Nouveau1234"}, headers=H(t))
    assert r.status_code in (400, 401, 403)


async def _reset_code(client, email, capsys):
    capsys.readouterr()
    r = await client.post("/auth/forgot-password", json={"identifier": email})
    assert r.status_code == 200
    out = capsys.readouterr().out
    import re

    m = re.search(r"\b(\d{6})\b", out)
    return m.group(1) if m else None


async def test_password_reset_flow(client, capsys):
    await register(client, "a@x.com")
    t, _ = await login(client, "a@x.com")
    code = await _reset_code(client, "a@x.com", capsys)
    assert code
    r = await client.post("/auth/reset-password", json={"identifier": "a@x.com", "code": code, "new_password": "Brandnew123"})
    assert r.status_code == 200, r.text
    assert (await client.get("/auth/me", headers=H(t))).status_code == 401  # sessions révoquées
    await login(client, "a@x.com", password="Brandnew123")


async def test_password_reset_unknown_email_is_generic(client):
    r = await client.post("/auth/forgot-password", json={"identifier": "nobody@x.com"})
    assert r.status_code == 200


async def test_password_reset_attempt_limit(client, capsys):
    await register(client, "a@x.com")
    code = await _reset_code(client, "a@x.com", capsys)
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(5):
        r = await client.post("/auth/reset-password", json={"identifier": "a@x.com", "code": wrong, "new_password": "Brandnew123"})
        assert r.status_code == 400
    r = await client.post("/auth/reset-password", json={"identifier": "a@x.com", "code": code, "new_password": "Brandnew123"})
    assert r.status_code == 400  # code bloqué après 5 essais


async def test_delete_account(client):
    t = await new_user(client, "a@x.com")
    r = await publish(client, t)
    assert r.status_code == 201
    r = await client.post("/auth/delete-account", json={"password": "Motdepasse1"}, headers=H(t))
    assert r.status_code == 200, r.text
    assert (await client.get("/auth/me", headers=H(t))).status_code == 401
    assert not any(PDF_DIR.iterdir())


# ------------------------------------------------------------------ documents
async def test_publish_and_get(client):
    t = await new_user(client, "a@x.com")
    r = await publish(client, t)
    assert r.status_code == 201, r.text
    d = r.json()
    assert d["titre"] == "Mon doc" and d["nb_likes"] == 0 and d["liked"] is False
    assert d["couverture_url"].startswith("/covers/")
    assert (await client.get(f"/documents/{d['id']}", headers=H(t))).json()["id"] == d["id"]
    # la couverture est servie publiquement
    assert (await client.get(d["couverture_url"])).status_code == 200


async def test_publish_rejects_fake_pdf(client):
    t = await new_user(client, "a@x.com")
    r = await client.post(
        "/documents",
        data={"titre": "x", "categorie": "Science", "langue": "Français"},
        files={"pdf": ("a.pdf", b"not a pdf", "application/pdf"), "couverture": ("c.png", PNG, "image/png")},
        headers=H(t),
    )
    assert r.status_code in (400, 415, 422)


async def test_publish_rejects_fake_cover_and_cleans_pdf(client):
    t = await new_user(client, "a@x.com")
    r = await client.post(
        "/documents",
        data={"titre": "x", "categorie": "Science", "langue": "Français"},
        files={"pdf": ("a.pdf", PDF, "application/pdf"), "couverture": ("c.png", b"nope", "image/png")},
        headers=H(t),
    )
    assert r.status_code in (400, 415, 422)
    assert not any(PDF_DIR.iterdir())


async def test_pdf_download_requires_auth(client):
    t = await new_user(client, "a@x.com")
    d = (await publish(client, t)).json()
    assert (await client.get(f"/documents/{d['id']}/fichier")).status_code in (401, 403)
    r = await client.get(f"/documents/{d['id']}/fichier", headers=H(t))
    assert r.status_code == 200 and r.content.startswith(b"%PDF")


async def test_search_and_filters(client):
    t = await new_user(client, "a@x.com")
    await publish(client, t, titre="Algèbre linéaire", categorie="Science")
    await publish(client, t, titre="Roman noir", categorie="Roman")
    r = (await client.get("/documents", params={"search": "alg"}, headers=H(t))).json()
    assert [d["titre"] for d in r["items"]] == ["Algèbre linéaire"]
    r = (await client.get("/documents", params={"categorie": "Roman"}, headers=H(t))).json()
    assert [d["titre"] for d in r["items"]] == ["Roman noir"]
    r = (await client.get("/documents", params={"search": "%"}, headers=H(t))).json()
    assert r["items"] == []  # le « % » est échappé


async def test_cursor_pagination(client):
    t = await new_user(client, "a@x.com")
    for i in range(5):
        await publish(client, t, titre=f"Doc {i}")
    p1 = (await client.get("/documents", params={"limit": 2}, headers=H(t))).json()
    assert [d["titre"] for d in p1["items"]] == ["Doc 4", "Doc 3"] and p1["next_cursor"]
    p2 = (await client.get("/documents", params={"limit": 2, "cursor": p1["next_cursor"]}, headers=H(t))).json()
    assert [d["titre"] for d in p2["items"]] == ["Doc 2", "Doc 1"]
    p3 = (await client.get("/documents", params={"limit": 2, "cursor": p2["next_cursor"]}, headers=H(t))).json()
    assert [d["titre"] for d in p3["items"]] == ["Doc 0"] and p3["next_cursor"] is None


async def test_likes(client):
    a = await new_user(client, "a@x.com")
    b = await new_user(client, "b@x.com")
    d = (await publish(client, a)).json()
    r = (await client.post(f"/documents/{d['id']}/like", headers=H(b))).json()
    assert r == {"liked": True, "nb_likes": 1}
    r = (await client.post(f"/documents/{d['id']}/like", headers=H(b))).json()
    assert r["nb_likes"] == 1  # idempotent
    assert (await client.get(f"/documents/{d['id']}", headers=H(b))).json()["liked"] is True
    r = (await client.delete(f"/documents/{d['id']}/like", headers=H(b))).json()
    assert r == {"liked": False, "nb_likes": 0}


async def test_popular_order(client):
    a = await new_user(client, "a@x.com")
    b = await new_user(client, "b@x.com")
    d1 = (await publish(client, a, titre="Un")).json()
    d2 = (await publish(client, a, titre="Deux")).json()
    await client.post(f"/documents/{d1['id']}/like", headers=H(a))
    await client.post(f"/documents/{d1['id']}/like", headers=H(b))
    await client.post(f"/documents/{d2['id']}/like", headers=H(b))
    items = (await client.get("/documents/populaires", headers=H(a))).json()["items"]
    assert [d["titre"] for d in items] == ["Un", "Deux"]


async def test_comments_and_permissions(client):
    a = await new_user(client, "a@x.com")  # auteur du document
    b = await new_user(client, "b@x.com")
    c = await new_user(client, "c@x.com")
    d = (await publish(client, a)).json()
    cm = (await client.post(f"/documents/{d['id']}/commentaires", json={"contenu": "Bravo"}, headers=H(b))).json()
    assert cm["contenu"] == "Bravo"
    assert (await client.post(f"/documents/{d['id']}/commentaires", json={"contenu": "   "}, headers=H(b))).status_code in (400, 422)
    items = (await client.get(f"/documents/{d['id']}/commentaires", headers=H(c))).json()["items"]
    assert len(items) == 1
    assert (await client.delete(f"/documents/commentaires/{cm['id']}", headers=H(c))).status_code == 403
    assert (await client.delete(f"/documents/commentaires/{cm['id']}", headers=H(a))).status_code == 200  # auteur du doc
    cm2 = (await client.post(f"/documents/{d['id']}/commentaires", json={"contenu": "Hello"}, headers=H(b))).json()
    assert (await client.delete(f"/documents/commentaires/{cm2['id']}", headers=H(b))).status_code == 200  # son auteur


async def test_library(client):
    a = await new_user(client, "a@x.com")
    b = await new_user(client, "b@x.com")
    d = (await publish(client, a)).json()
    assert (await client.post(f"/documents/bibliotheque/{d['id']}", headers=H(b))).status_code == 201
    assert (await client.post(f"/documents/bibliotheque/{d['id']}", headers=H(b))).status_code == 201  # idempotent
    lib = (await client.get("/documents/bibliotheque", headers=H(b))).json()
    assert len(lib) == 1 and lib[0]["dans_bibliotheque"] is True
    assert (await client.get("/documents/bibliotheque", headers=H(a))).json() == []
    await client.delete(f"/documents/bibliotheque/{d['id']}", headers=H(b))
    assert (await client.get("/documents/bibliotheque", headers=H(b))).json() == []


async def test_delete_document_permissions_and_files(client):
    a = await new_user(client, "a@x.com")
    b = await new_user(client, "b@x.com")
    d = (await publish(client, a)).json()
    assert (await client.delete(f"/documents/{d['id']}", headers=H(b))).status_code == 403
    assert (await client.delete(f"/documents/{d['id']}", headers=H(a))).status_code == 200
    assert (await client.get(f"/documents/{d['id']}", headers=H(a))).status_code == 404
    assert not any(PDF_DIR.iterdir()) and not any(COVER_DIR.iterdir())


# ------------------------------------------------------------------ réseau social
async def test_follow_and_feed(client):
    a = await new_user(client, "a@x.com")
    b = await new_user(client, "b@x.com")
    me_a = (await client.get("/auth/me", headers=H(a))).json()
    await publish(client, a, titre="De A")
    await publish(client, b, titre="De B")
    assert (await client.get("/documents/feed", headers=H(b))).json()["items"] == []
    r = await client.post(f"/users/{me_a['id']}/follow", headers=H(b))
    assert r.status_code == 200 and r.json()["is_following"] is True
    feed = (await client.get("/documents/feed", headers=H(b))).json()["items"]
    assert [d["titre"] for d in feed] == ["De A"]
    prof = (await client.get(f"/users/{me_a['id']}/profile", headers=H(b))).json()
    assert prof["nb_abonnes"] == 1 and prof["nb_documents"] == 1 and prof["is_following"] is True
    abonnes = (await client.get(f"/users/{me_a['id']}/abonnes", headers=H(b))).json()["items"]
    assert len(abonnes) == 1
    await client.delete(f"/users/{me_a['id']}/follow", headers=H(b))
    assert (await client.get("/documents/feed", headers=H(b))).json()["items"] == []


async def test_cannot_follow_self(client):
    a = await new_user(client, "a@x.com")
    me = (await client.get("/auth/me", headers=H(a))).json()
    assert (await client.post(f"/users/{me['id']}/follow", headers=H(a))).status_code == 400


async def test_user_search(client):
    a = await new_user(client, "a@x.com")
    await register(client, "z@x.com", nom="Zorro", prenom="Don")
    r = (await client.get("/users/search", params={"q": "zor"}, headers=H(a))).json()["items"]
    assert len(r) == 1 and "Zorro" in r[0]["nom"] + r[0].get("prenom", "")
    assert (await client.get("/users/search", params={"q": "z"}, headers=H(a))).status_code == 422


# ------------------------------------------------------------------ admin
async def _admin(client):
    t, _ = await login(client, "admin@test.local", password="AdminPass123", device="adm")
    return t


async def test_admin_forbidden_for_members(client):
    a = await new_user(client, "a@x.com")
    assert (await client.get("/admin/stats", headers=H(a))).status_code == 403
    assert (await client.get("/admin/users", headers=H(a))).status_code == 403


async def test_admin_stats_and_users(client):
    a = await new_user(client, "a@x.com")
    await publish(client, a)
    adm = await _admin(client)
    s = (await client.get("/admin/stats", headers=H(adm))).json()
    assert s["total_utilisateurs"] == 2 and s["total_documents"] == 1 and s["connexions_actives"] >= 2
    users = (await client.get("/admin/users", params={"search": "a@x"}, headers=H(adm))).json()["items"]
    assert len(users) == 1


async def test_admin_disable_enable_document(client):
    a = await new_user(client, "a@x.com")
    d = (await publish(client, a)).json()
    adm = await _admin(client)
    assert (await client.put(f"/admin/documents/{d['id']}/disable", headers=H(adm))).status_code == 200
    assert (await client.get(f"/documents/{d['id']}", headers=H(a))).status_code == 404
    assert (await client.get("/documents", headers=H(a))).json()["items"] == []
    desact = (await client.get("/admin/documents", params={"etat": "desactives"}, headers=H(adm))).json()["items"]
    assert len(desact) == 1
    await client.put(f"/admin/documents/{d['id']}/enable", headers=H(adm))
    assert (await client.get(f"/documents/{d['id']}", headers=H(a))).status_code == 200


async def test_admin_role_and_self_protection(client):
    a = await new_user(client, "a@x.com")
    uid = (await client.get("/auth/me", headers=H(a))).json()["id"]
    adm = await _admin(client)
    admin_id = (await client.get("/auth/me", headers=H(adm))).json()["id"]
    r = await client.put(f"/admin/users/{uid}/role", json={"role": "admin"}, headers=H(adm))
    assert r.status_code == 200 and r.json()["role"] == "admin"
    assert (await client.get("/admin/stats", headers=H(a))).status_code == 200
    assert (await client.put(f"/admin/users/{admin_id}/role", json={"role": "membre"}, headers=H(adm))).status_code == 400
    assert (await client.put(f"/admin/users/{uid}/role", json={"role": "root"}, headers=H(adm))).status_code == 422
    assert (await client.delete(f"/admin/users/{admin_id}", headers=H(adm))).status_code == 400


async def test_admin_delete_user_cascades(client):
    a = await new_user(client, "a@x.com")
    b = await new_user(client, "b@x.com")
    uid = (await client.get("/auth/me", headers=H(a))).json()["id"]
    d = (await publish(client, a)).json()
    await client.post(f"/documents/{d['id']}/like", headers=H(b))
    await client.post(f"/documents/{d['id']}/commentaires", json={"contenu": "yo"}, headers=H(b))
    adm = await _admin(client)
    assert (await client.delete(f"/admin/users/{uid}", headers=H(adm))).status_code == 200
    assert (await client.get(f"/documents/{d['id']}", headers=H(b))).status_code == 404
    assert (await client.get("/auth/me", headers=H(a))).status_code == 401
    assert not any(PDF_DIR.iterdir()) and not any(COVER_DIR.iterdir())
    s = (await client.get("/admin/stats", headers=H(adm))).json()
    assert s["total_likes"] == 0 and s["total_commentaires"] == 0


async def test_health(client):
    assert (await client.get("/")).json()["app"] == "Yaarexbook"
