"""Envoi du code de réinitialisation du mot de passe.

Sans configuration SMTP (cas du développement local), le code est affiché dans la
console du serveur."""
import asyncio
import smtplib
from email.message import EmailMessage

from app.config import MAIL_FROM, SMTP_HOST, SMTP_PASSWORD, SMTP_PORT, SMTP_USER


def _send_sync(to: str, subject: str, body: str) -> None:
    msg = EmailMessage()
    msg["From"] = MAIL_FROM
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as server:
        server.starttls()
        if SMTP_USER:
            server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)


async def send_reset_code(email: str, code: str, minutes: int) -> None:
    subject = "Yaarexbook : réinitialisation de votre mot de passe"
    body = (
        f"Votre code de réinitialisation est : {code}\n\n"
        f"Il est valable {minutes} minutes. Si vous n'êtes pas à l'origine de cette demande, ignorez ce message."
    )
    if not SMTP_HOST:
        print(f"[Yaarexbook] Code de réinitialisation pour {email} : {code} (valable {minutes} min)")
        return
    try:
        await asyncio.to_thread(_send_sync, email, subject, body)
    except Exception as exc:  # ne doit jamais révéler si le compte existe
        print(f"[Yaarexbook] Échec d'envoi de l'email à {email}: {exc}")
