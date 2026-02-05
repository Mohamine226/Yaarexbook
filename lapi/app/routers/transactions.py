from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import delete, func, select

from app.database import get_db
import app.models as models
import app.schemas as schemas
from fastapi import Query


router = APIRouter(prefix="/wallets", tags=["wallets"])

# -------------------------------
# 🔹 ROUTES WALLET
# -------------------------------

#Creation de wallets
@router.post("/", response_model=schemas.Wallet)
async def create_wallet(wallet: schemas.WalletCreate, db: AsyncSession = Depends(get_db)):
    db_wallet = models.Wallet(**wallet.dict())
    db.add(db_wallet)
    await db.commit()
    await db.refresh(db_wallet)
    return db_wallet

# Supprimsion de tous les wallets
@router.delete("/wallets")
async def delete_all_wallets(db: AsyncSession = Depends(get_db)):
    # Supprimer tous les wallets
    await db.execute(delete(models.Wallet))
    await db.commit()
    return {"status": "success", "message": "Tous les wallets ont été supprimés"}


# Recuperation des information d'un vendeur
@router.get("/{vendeur_id}", response_model=schemas.WalletWithTransactions)
async def get_wallet(
    vendeur_id: int,
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),      # nombre d’éléments à ignorer
    limit: int = Query(10, ge=1),    # nombre d’éléments à retourner
):
    # 1️⃣ Récupérer le wallet
    result = await db.execute(
        select(models.Wallet).where(models.Wallet.vendeur_id == vendeur_id)
    )
    wallet = result.scalars().first()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    # 2️⃣ Récupérer les transactions avec pagination
    tx_result = await db.execute(
        select(models.Transaction)
        .where(models.Transaction.wallet_id == wallet.id)
        .offset(skip)
        .limit(limit)
    )
    transactions = tx_result.scalars().all()

    # 3️⃣ Retourner le wallet avec transactions paginées
    return {
        "id": wallet.id,
        "vendeur_id": wallet.vendeur_id,
        "solde": wallet.solde,
        "date_creation": wallet.date_creation,
        "transactions": transactions
    }

# Recuperation du solde d'un vendeur
@router.get("/{user_id}/solde")
async def get_solde(user_id: int, db: AsyncSession = Depends(get_db)):
    # Vérifier que le wallet existe pour ce user_id
    result = await db.execute(select(models.Wallet).where(models.Wallet.user_id == user_id))
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet introuvable")
    
    # Retourner le solde disponible
    return {
        "user_id": user_id,
        "solde_disponible": wallet.solde,
    }

# Recuperation de nombre de ventes des vendeurs
@router.get("/wallets/ventes-par-vendeur")
async def get_ventes_par_vendeur(db: AsyncSession = Depends(get_db)):
    query = (
        select(models.Document.vendeur_id, func.count(models.Transaction.id).label("nombre_ventes"))
        .join(models.Transaction, models.Transaction.document_id == models.Document.id)
        .where(models.Transaction.type == "achat")
        .group_by(models.Document.vendeur_id)
    )
    result = await db.execute(query)
    ventes = result.all()
    return [{"vendeur_id": v_id, "nombre_ventes": nb} for v_id, nb in ventes]

# Recuperation de nombre de ventes d'un vendeurs
@router.get("/{user_id}/ventes")
async def get_ventes_par_user(user_id: int, db: AsyncSession = Depends(get_db)):
    query = (
        select(func.count(models.Transaction.id))
        .join(models.Document, models.Transaction.document_id == models.Document.id)
        .where(models.Transaction.type == "achat")
        .where(models.Document.vendeur_id == user_id)  # ✅ correction
    )
    result = await db.execute(query)
    nb_ventes = result.scalar() or 0
    return {"user_id": user_id, "nombre_ventes": nb_ventes}


# Nombre de documents acheter par un utilisateur
@router.get("/users/{user_id}/documents-achetes")
async def get_nombre_documents_achetes(user_id: int, db: AsyncSession = Depends(get_db)):
    # Compter le nombre de documents achetés par un utilisateur
    query = (
        select(func.count(models.Transaction.id))
        .where(models.Transaction.user_id == user_id)
        .where(models.Transaction.type == "achat")
    )

    result = await db.execute(query)
    nombre_achetes = result.scalar()

    if nombre_achetes is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable ou aucun achat")

    return {
        "user_id": user_id,
        "documents_achetes": nombre_achetes
    }




# Un post de retrait
@router.post("/{wallet_id}/retrait", response_model=schemas.RetraitResponse)
async def effectuer_retrait(
    wallet_id: int,
    retrait: schemas.RetraitCreate,  # montant, référence, etc.
    db: AsyncSession = Depends(get_db),
):
    # 1️⃣ Vérifier que le wallet existe
    result = await db.execute(select(models.Wallet).where(models.Wallet.id == wallet_id))
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet introuvable")

    # 2️⃣ Vérifier solde suffisant 
    if retrait.montant > wallet.solde:
        raise HTTPException(status_code=400, detail="Solde insuffisant")

    # 3️⃣ Créer la transaction de retrait
    transaction = models.Transaction(
        wallet_id=wallet_id,
        type="retrait",
        montant=retrait.montant,
        status="success",
        reference=retrait.reference,
    )
    db.add(transaction)

    # 4️⃣ Mettre à jour le solde du wallet
    wallet.solde -= retrait.montant

    await db.commit()
    await db.refresh(transaction)

    # 5️⃣ Retourner la transaction avec info supplémentaire
    message = (
        "Retrait total effectué" if wallet.solde == 0
        else "Retrait partiel effectué"
    )

    return {
        "id": transaction.id,
        "wallet_id": transaction.wallet_id,
        "type": transaction.type,
        "montant": transaction.montant,
        "status": transaction.status,
        "reference": transaction.reference,
        "date_transaction": transaction.date_transaction,
        "message": message,
        "solde_restant": wallet.solde,
    }



# Recuperation des transaction du retrait
@router.get("/transactions/retraits", response_model=list[schemas.Transaction])
async def get_retraits(
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),   # pagination : ignorer les premiers "skip"
    limit: int = Query(10, ge=1), # pagination : limiter à "limit"
):
    result = await db.execute(
        select(models.Transaction)
        .where(models.Transaction.type == "retrait")   #  filtrer uniquement les retraits
        .offset(skip)
        .limit(limit)
    )
    transactions = result.scalars().all()
    if not transactions:
        raise HTTPException(status_code=404, detail="Aucun retrait trouvé")
    return transactions

#  Récupérer les transactions de retrait d’un vendeurs précis avec pagination
@router.get("/{userd_id}/retrait", response_model=list[schemas.Transaction])
async def get_retrait_par_vendeur(
    userd_id: int,
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1),
):
    result = await db.execute(
        select(models.Transaction)
        #.where(models.Transaction.wallet_id == wallet_id)
        .where(models.Transaction.type == "retrait")   # ✅ filtrer uniquement les retraits
        .offset(skip)
        .limit(limit)
    )
    retrait = result.scalars().all()
    return retrait



# -------------------------------
#  ROUTES TRANSACTIONS
# -------------------------------

#Post de transaction


# 1️⃣ Récupérer toutes les transactions avec pagination
@router.get("/transactions/", response_model=list[schemas.Transaction])
async def get_all_transactions(
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),      # nombre d’éléments à ignorer
    limit: int = Query(10, ge=1),    # nombre d’éléments à retourner
):
    result = await db.execute(
        select(models.Transaction).offset(skip).limit(limit)
    )
    transactions = result.scalars().all()
    if not transactions:
        raise HTTPException(status_code=404, detail="Aucune transaction trouvée")
    return transactions

# 2️⃣ Récupérer les transactions des documents payer d'un walled precis wallet précis avec pagination
@router.get("/{wallet_id}/transaction", response_model=list[schemas.Transaction])
async def get_Transac_reception_par_vendeur(
    wallet_id: int,
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1),
):
    result = await db.execute(
        select(models.Transaction)
        .where(models.Transaction.wallet_id == wallet_id)
        .offset(skip)
        .limit(limit)
    )
    reception = result.scalars().all()
    return reception



# Post des achats
@router.post("/achats/", response_model=schemas.Transaction)
async def create_achat(transaction: schemas.AchatCreate, db: AsyncSession = Depends(get_db)):
    # 1️⃣ Récupérer le document
    result = await db.execute(
        select(models.Document).where(models.Document.id == transaction.document_id)
    )
    document = result.scalars().first()
    if not document:
        raise HTTPException(status_code=404, detail="Document introuvable")

    # 2️⃣ Récupérer le wallet du vendeur lié au document
    result_wallet = await db.execute(
        select(models.Wallet).where(models.Wallet.user_id == document.vendeur_id)  # ✅ correction
    )
    wallet = result_wallet.scalars().first()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet du vendeur introuvable")

    # 3️⃣ Créer la transaction avec wallet_id du vendeur
    db_transaction = models.Transaction(
        wallet_id=wallet.id,
        acheteur_id=transaction.acheteur_id,
        type="achat",
        montant=transaction.montant,
        document_id=transaction.document_id,
        document_nom=transaction.document_nom,
        status="success",
        reference=transaction.reference,
    )
    db.add(db_transaction)

    # 4️⃣ Mettre à jour le solde du wallet vendeur
    wallet.solde += transaction.montant * 0.9
    

    await db.commit()
    await db.refresh(db_transaction)
    return db_transaction

# Recupearation des transaction d'un vendeur
@router.get("/achats/{user_id}", response_model=list[schemas.Transaction])
async def get_achats(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1),
):
    result = await db.execute(
        select(models.Transaction)
        .where(models.Transaction.acheteur_id == user_id)   # ✅ filtrer par acheteur
        .offset(skip)
        .limit(limit)
    )
    transactions = result.scalars().all()
    return transactions

# Suppression de tous les transaction de la Transaction
@router.delete("/achats")
async def suppimer_tous_achats(db: AsyncSession = Depends(get_db)):
    # Supprimer toutes les transactions
    await db.execute(delete(models.Transaction))
    
    # Réinitialiser les soldes des wallets
    result = await db.execute(select(models.Wallet))
    wallets = result.scalars().all()
    for wallet in wallets:
        wallet.solde = 0

    await db.commit()
    return {"status": "success", "message": "Toutes les transactions ont été supprimées et les soldes réinitialisés"}