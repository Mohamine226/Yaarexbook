from fastapi_mail import FastMail, MessageSchema, ConnectionConfig # type: ignore
from twilio.rest import Client # type: ignore
import os
import requests

conf = ConnectionConfig(
    MAIL_USERNAME="apikey",  # toujours "apikey" pour Brevo
    MAIL_PASSWORD="xsmtpsib-e53d66654d75449eb3ded601e2f01516d1127f2e5e66452aff6121b6da814e8b-SJiR0Ut44xK5fuoh",  # clé SMTP Brevo
    MAIL_FROM="myebookbf@gmail.com",  # ou ton mail vérifié Brevo
    MAIL_PORT=587,
    MAIL_SERVER="smtp-relay.brevo.com",
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

fm = FastMail(conf)

async def send_reset_email(email: str, code: str):
    message = MessageSchema(
        subject="Réinitialisation de mot de passe",
        recipients=[email],
        body=f"Voici votre code de réinitialisation : {code}",
        subtype="plain"
    )
    await fm.send_message(message)



# Variables d'environnement pour Brevo
brevo_api_key = os.getenv("BREVO_API_KEY")

def send_reset_sms(phone: str, code: str):
    url = "https://api.brevo.com/v3/transactionalSMS/sms"
    payload = {
        "sender": "MyEbook",  # expéditeur validé dans Brevo
        "recipient": phone, # numéro au format international (+226...)
        "content": f"Votre code de réinitialisation est : {code}",
        "type": "transactional"
    }
    headers = {
        "accept": "application/json",
        "api-key": brevo_api_key,
        "content-type": "application/json"
    }

    response = requests.post(url, json=payload, headers=headers)

    if response.status_code == 201:
        print(response.json().get("messageId"))
    else:
        print("Erreur :", response.json())


#  Mets tes vraies clés Twilio dans des variables d'environnement
account_sid = "TON_ACCOUNT_SID"
auth_token = "TON_AUTH_TOKEN"
client = Client(account_sid, auth_token)

def send_reset_sms_twilio(phone: str, code: str):
    message = client.messages.create(
        body=f"Votre code de réinitialisation est : {code}",
        from_="+1234567890",  # numéro Twilio
        to=phone
    )
    print(message.sid)