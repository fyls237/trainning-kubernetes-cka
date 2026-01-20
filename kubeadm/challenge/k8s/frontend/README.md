# 🎨 Portfolio Frontend - Architecture & Déploiement

Ce dossier contient les manifestes Kubernetes pour le Frontend de l'application Portfolio.
L'application est une Single Page Application (SPA) moderne construite avec **React**, **Vite**, et **Tailwind CSS**.

---

## 🏗️ Architecture Technique

*   **Framework JS** : React 18 + Vite (Build ultra-rapide)
*   **Styling** : Tailwind CSS + Framer Motion (Animations fluides)
*   **Serveur Web** : Nginx (Alpine) - Sert les fichiers statiques et gère le routing SPA.
*   **Image Docker** : Multi-stage build (~20Mo finale).

### Le flux de la requête :
1.  L'utilisateur accède au site via l'**Ingress** (ex: `mon-domaine.com`).
2.  L'Ingress route `/` vers le Service `portfolio-frontend`.
3.  Le Pod Frontend (Nginx) renvoie `index.html`.
4.  L'application React se charge dans le navigateur.
5.  React fait des appels API vers `/api/projects`.
6.  L'Ingress intercepte `/api/` et route vers le Service `portfolio-backend`.

---

## 📦 Dockerisation (Multi-Stage)

Le `Dockerfile` est optimisé en deux étapes pour réduire la taille de l'image et sécuriser le code :

1.  **Builder Stage (`node:18-alpine`)** :
    *   Installe les dépendances (`npm install`).
    *   Compile le code React en HTML/CSS/JS statique (`npm run build`).
    *   Résultat : un dossier `/dist`.

2.  **Production Stage (`nginx:alpine`)** :
    *   Récupère *uniquement* le dossier `/dist` du stage précédent.
    *   Utilise une configuration Nginx personnalisée (`nginx.conf`) pour gérer le mode SPA (rediriger 404 vers index.html).

**Commandes de Build :**
```bash
cd app/frontend
docker build -t ghcr.io/<USER>/portfolio-frontend:v1 .
docker push ghcr.io/<USER>/portfolio-frontend:v1
```

---

## 🚀 Déploiement Kubernetes

L'application est déployée via :
*   `deployment.yaml` : 2 Réplicas pour la haute disponibilité.
*   `service.yaml` : ClusterIP (Port 80) pour une exposition interne.

```bash
kubectl apply -f k8s/frontend/
```

### Vérification
```bash
kubectl get pods -n prod-database -l tier=frontend
```
