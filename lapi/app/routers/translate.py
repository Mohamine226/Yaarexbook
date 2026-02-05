from fastapi import APIRouter
import httpx # type: ignore

router = APIRouter(prefix="/IA", tags=["translate"])

@router.post("/translate")
async def translate_text(q: str, source: str = "auto", target: str = "fr", format: str = "text"):
    """
    Route FastAPI asynchrone pour traduire un texte avec LibreTranslate
    """
    url = "https://libretranslate.com/translate"
    payload = {
        "q": q,
        "source": source,
        "target": target,
        "format": format,
        "alternatives": 3,
        "api_key": ""  # facultatif, pas nécessaire pour l'instance publique
    }
    headers = {"Content-Type": "application/json"}

    async with httpx.AsyncClient() as client:
        res = await client.post(url, json=payload, headers=headers)
        return res.json()