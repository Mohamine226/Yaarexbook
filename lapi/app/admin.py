from app.database import AsyncSessionLocal
from app.models import User
import asyncio

async def create_admin():
    async with AsyncSessionLocal() as db:
        admin = User(
            email="admin@daaga.com",
            password="admin123",   # ⚠️ en clair pour tester
            role="admin",
            nom="Admin",
            prenom="User",
            pays="Burkina Faso",
            telephone="+22600000000",
            profession="Administrateur",
            is_verified=True
        )
        db.add(admin)
        await db.commit()
        await db.refresh(admin)
        print("✅ Admin créé avec ID:", admin.id)

asyncio.run(create_admin())