from fastapi_mail import FastMail, MessageSchema, ConnectionConfig # type: ignore
from twilio.rest import Client # type: ignore

# ⚠️ Mets tes vraies infos ou variables d'environnement
conf = ConnectionConfig(
    MAIL_USERNAME="ton_email@gmail.com",          # adresse email complète
    MAIL_PASSWORD="ton_mot_de_passe_app",         # mot de passe d'application Gmail
    MAIL_FROM="ton_email@gmail.com",              # doit contenir un @
    MAIL_PORT=587,
    MAIL_SERVER="smtp.gmail.com",
    MAIL_STARTTLS=True,                           # obligatoire
    MAIL_SSL_TLS=False,                           # obligatoire
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

async def send_reset_email(email: str, code: str):
    message = MessageSchema(
        subject="Code de réinitialisation",
        recipients=[email],
        body=f"Votre code de réinitialisation est : {code}",
        subtype="plain"
    )
    fm = FastMail(conf)
    await fm.send_message(message)

# ⚠️ Mets tes vraies clés Twilio dans des variables d'environnement
account_sid = "TON_ACCOUNT_SID"
auth_token = "TON_AUTH_TOKEN"
client = Client(account_sid, auth_token)

def send_reset_sms(phone: str, code: str):
    message = client.messages.create(
        body=f"Votre code de réinitialisation est : {code}",
        from_="+1234567890",  # numéro Twilio
        to=phone
    )
    print(message.sid)