from fastapi import APIRouter
from pydantic import BaseModel
import os
from openai import OpenAI  # type: ignore

router = APIRouter(prefix="/IA", tags=["explain"])

class ExplainRequest(BaseModel):
    prompt: str

API_KEY = os.environ.get("HF_TOKEN")

client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=API_KEY
)

@router.post("/explain")
async def explain_text(body: ExplainRequest):
    if not API_KEY:
        return {"error": "HF_TOKEN manquant. Définis la variable d'environnement."}

    completion = client.chat.completions.create(
        model="moonshotai/Kimi-K2-Instruct-0905",
        messages=[
            {
                "role": "user",
                "content": f"Explique étape par étape : {body.prompt}"
            }
        ],
    )

    msg = completion.choices[0].message
    return {
        "response": {
            "role": msg.role,
            "content": msg.content
        }
    }