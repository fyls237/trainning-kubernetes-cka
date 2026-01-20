# Utilisation d'une image légère officielle Python
FROM python:3.9-slim

# Définition du répertoire de travail
WORKDIR /app

# Installation des dépendances système pour psycopg2 (libpq-dev est nécessaire pour le build)
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copie des fichiers de dépendances
COPY requirements.txt .

# Installation des packages Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY main.py .

# Création d'un utilisateur non-root pour la sécurité (Best Practice Container)
RUN useradd -m appuser && chown -R appuser /app
USER appuser

# Exposition du port 8000
EXPOSE 8000

# Commande de lancement (Uvicorn server)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
