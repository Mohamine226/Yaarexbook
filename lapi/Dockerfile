# Étape 1 : Choisir une image Python
FROM python:3.11-slim

# Étape 2 : Définir le répertoire de travail
WORKDIR /app

# Étape 3 : Copier les fichiers de requirements
COPY requirements.txt .

# Étape 4 : Installer les dépendances
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt


# Étape 5 : Copier tout le projet dans le conteneur
COPY . .


# Étape 6 : Exposer le port (FastAPI par défaut : 8000)
EXPOSE 8000

# Étape 7 : Commande de lancement (Uvicorn pour FastAPI)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]


