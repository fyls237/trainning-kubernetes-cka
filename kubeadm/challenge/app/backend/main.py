import os
import json
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
import redis
import time

# --- Configuration ---
# On utilise des variables d'environnement, c'est la "Cloud Native Way" (12-Factor App)
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_DB = os.getenv("PG_DB", "portfolio_db")
PG_USER = os.getenv("PG_USER", "postgres")
PG_PASSWORD = os.getenv("PG_PASSWORD", "password")

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

app = FastAPI(title="Portfolio API", description="API pour gérer un portfolio DevOps avec cache Redis")

# --- Modèles de Données (Pydantic) ---
class Project(BaseModel):
    title: str
    description: str
    tech_stack: List[str]
    repo_url: Optional[str] = None

class ProjectResponse(Project):
    id: int
    created_at: str

# --- Clients Database & Cache ---

# Fonction pour obtenir une connexion DB (avec retry simple pour le démarrage K8s)
def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=PG_HOST,
            database=PG_DB,
            user=PG_USER,
            password=PG_PASSWORD
        )
        return conn
    except Exception as e:
        print(f"Erreur connexion DB: {e}")
        raise HTTPException(status_code=503, detail="Database not available")

# Client Redis
r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

# --- Initialisation de la Table ---
@app.on_event("startup")
def startup_event():
    # On attend un peu que la DB soit prête si on est dans un pod qui démarre vite
    time.sleep(2) 
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id SERIAL PRIMARY KEY,
                title VARCHAR(100) NOT NULL,
                description TEXT,
                tech_stack TEXT[],
                repo_url VARCHAR(200),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
        print("Table 'projects' vérifiée/créée.")
    except Exception as e:
        print(f"Startup Warning: Impossible d'init la DB ({e}). On réessaiera à la requête.")

# --- Routes API ---

@app.get("/")
def read_root():
    return {"message": "Bienvenue sur l'API Portfolio DevOps v1.0"}

@app.get("/health")
def health_check():
    """Vérifie la santé des dépendances (DB + Redis)"""
    health = {"api": "ok", "db": "unknown", "redis": "unknown"}
    
    # Check DB
    try:
        conn = get_db_connection()
        conn.close()
        health["db"] = "ok"
    except:
        health["db"] = "failed"

    # Check Redis
    try:
        r.ping()
        health["redis"] = "ok"
    except:
        health["redis"] = "failed"

    return health

@app.post("/projects", response_model=ProjectResponse, status_code=201)
def create_project(project: Project):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        cur.execute(
            """
            INSERT INTO projects (title, description, tech_stack, repo_url)
            VALUES (%s, %s, %s, %s)
            RETURNING *;
            """,
            (project.title, project.description, project.tech_stack, project.repo_url)
        )
        new_project = cur.fetchone()
        conn.commit()
        
        # Invalidation du cache Redis (car on a ajouté une donnée)
        r.delete("all_projects")
        
        # Convertir le datetime pour le JSON
        new_project['created_at'] = str(new_project['created_at'])
        return new_project
        
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.get("/projects", response_model=List[ProjectResponse])
def get_projects():
    # 1. Essayer de lire depuis Redis (Cache)
    try:
        cached_data = r.get("all_projects")
        if cached_data:
            print("LOG: Cache Hit ! Données venant de Redis.")
            return json.loads(cached_data)
    except Exception as e:
        print(f"Redis Warning: {e}")

    # 2. Si pas dans le cache, lire depuis PostgreSQL (Source of Truth)
    print("LOG: Cache Miss. Lecture DB...")
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT * FROM projects ORDER BY created_at DESC;")
    projects = cur.fetchall()
    
    # Conversion date pour serialisation
    for p in projects:
        p['created_at'] = str(p['created_at'])
    
    cur.close()
    conn.close()

    # 3. Stocker dans Redis pour la prochaine fois (TTL 60 secondes)
    try:
        r.setex("all_projects", 60, json.dumps(projects))
    except Exception as e:
         print(f"Redis Write Warning: {e}")

    return projects
