# 🐍 Portfolio Backend API - Guide d'Apprentissage

Ce dossier contient le code source et les manifestes Kubernetes pour l'API Backend du Portfolio.
Ce projet a servi de cas pratique pour explorer le cycle de vie complet d'une application Cloud Native : du code Python au déploiement sécurisé sur Kubernetes.

---

## 🏗️ Architecture Technique

*   **Langage** : Python 3.9 (FastAPI)
*   **Base de Données** : PostgreSQL (Stockage Persistant sur NFS)
*   **Cache** : Redis (Pour optimiser les lectures)
*   **Container Registry** : GitHub Container Registry (GHCR) - Privé
*   **Sécurité** : Sealed Secrets (Chiffrement des identifiants)

---

## 🚀 Étapes de Réalisation (Mémo)

### 1. Développement de l'API (`main.py`)
Nous avons créé une API REST simple avec 2 endpoints principaux :
*   `POST /projects` : Ajoute un projet dans PostgreSQL et invalide le cache Redis.
*   `GET /projects` : Vérifie d'abord Redis (Cache Hit). Si vide, interroge PostgreSQL (Cache Miss) et remplit Redis.

> **Point Clé** : L'API est résiliente. Elle utilise des blocs `try/except` pour ne pas crasher si la DB n'est pas encore prête au démarrage du Pod.

### 2. Conteneurisation (`Dockerfile`)
Nous avons packagé l'application dans une image Docker légère.
*   **Build** : `docker build -t portfolio-backend:local .`
*   **Push** : `docker push ghcr.io/<USER>/portfolio-backend:v1`

### 3. Gestion des Secrets (GitOps Friendly) 🔒
L'image étant hébergée sur un registre privé (GHCR), Kubernetes a besoin d'un "Passe-partout" pour la télécharger.
Au lieu de créer un Secret manuellement (dangereux à stocker dans Git), nous avons utilisé **Sealed Secrets**.

1.  **Création du Secret (Dry Run)** : Génération du YAML avec les identifiants Docker locaux.
2.  **Chiffrement (`kubeseal`)** : Utilisation de la clé publique du cluster pour sceller le secret.
    ```bash
    kubeseal --cert pub-cert.pem < secret-clair.yaml > ghcr-sealed-secret.yaml
    ```
3.  **Résultat** : Le fichier `ghcr-sealed-secret.yaml` peut être commité sur GitHub sans risque. Seul le contrôleur dans le cluster peut le déchiffrer.

### 4. Déploiement Kubernetes (`backend-deployment.yaml`)
Le manifeste définit :
*   **Deployment** : 2 Réplicas pour la haute disponibilité.
*   **Env Vars** : Injection des adresses de la DB (`postgres-service`) et de Redis (`redis-service`).
*   **Readiness Probe** : Kubernetes vérifie `/health` avant d'envoyer du trafic. Si la DB est down, le Pod est marqué "NotReady".

---

## 🛠️ Commandes Utiles (Cheat Sheet)

### Déploiement
```bash
# 1. Appliquer le Secret
kubectl apply -f ghcr-sealed-secret.yaml

# 2. Déployer l'App
kubectl apply -f backend-deployment.yaml
```

### Troubleshooting
Si le Pod ne démarre pas ou reste à `0/1` :
```bash
# Voir les logs (pourquoi ça plante ?)
kubectl logs -n prod-database -l app=portfolio-backend

# Voir les détails (Probe failed ?)
kubectl describe pod -n prod-database -l app=portfolio-backend
```

### Initialisation de la Base de Données
Si vous voyez l'erreur : `FATAL: database "portfolio_db" does not exist`.

C'est parce que l'image Postgres officielle crée seulement la base `postgres` par défaut.
**Solution manuelle (One-Shot)** :
```bash
kubectl exec -it postgres-0 -n prod-database -- psql -U postgres -c "CREATE DATABASE portfolio_db;"
```
*(Ensuite, redémarrer les pods backend pour qu'ils créent les tables)*.

### Test de l'API (Port-Forward)
Pour accéder à l'API depuis votre machine locale (sans Ingress) :
```bash
kubectl port-forward svc/portfolio-backend-service 8080:80 -n prod-database
```
Puis :
```bash
curl http://localhost:8080/projects
```

---

## 🧠 Leçons Apprises (Troubleshooting Avancé)
Lors de ce lab, nous avons rencontré un problème réseau majeur (Timeout, Connection Refused).
*   **Symptôme** : Pods `Running` mais inaccessibles (Readiness Probe Failure).
*   **Cause** : La stack réseau (CNI Calico) du nœud Worker était corrompue suite à un changement de disque.
*   **Solution** : Un redémarrage complet du nœud (`sudo reboot`) a permis de remettre d'équerre les interfaces réseaux et les routes.

*"Dans Kubernetes, c'est toujours le DNS... sauf quand c'est le réseau."*
