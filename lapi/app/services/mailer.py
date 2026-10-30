"""Envoi du code de réinitialisation du mot de passe via Brevo.

Sans BREVO_API_KEY (développement local), le code est affiché dans la console du serveur."""
import httpx

from app.config import BREVO_API_KEY, MAIL_FROM_EMAIL, MAIL_FROM_NAME

BREVO_URL = "https://api.brevo.com/v3/smtp/email"


async def send_reset_code(email: str, code: str, minutes: int) -> None:
    if not BREVO_API_KEY or not MAIL_FROM_EMAIL:
        print(f"[Yaarexbook] Code de réinitialisation pour {email} : {code} (valable {minutes} min)")
        return

    payload = {
        "sender": {"name": MAIL_FROM_NAME, "email": MAIL_FROM_EMAIL},
        "to": [{"email": email}],
        "subject": "Yaarexbook : votre code de vérification",
        "htmlContent": (
            "<div style='font-family:Arial,sans-serif'>"
            "<p>Bonjour,</p>"
            "<p>Votre code de vérification est :</p>"
            f"<p style='font-size:30px;font-weight:bold;letter-spacing:6px'>{code}</p>"
            f"<p>Il est valable {minutes} minutes. "
            "Si vous n'êtes pas à l'origine de cette demande, ignorez ce message.</p>"
            "</div>"
        ),
    }
    headers = {"api-key": BREVO_API_KEY, "accept": "application/json", "content-type": "application/json"}

    try:
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.post(BREVO_URL, json=payload, headers=headers)
        if r.status_code >= 300:
            print(f"[Yaarexbook] Brevo a refusé l'envoi à {email} : {r.status_code} {r.text}")
    except Exception as exc:
        print(f"[Yaarexbook] Échec d'envoi de l'email à {email} : {exc}")