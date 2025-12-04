### 🚀 Projet "Phoenix" : La Migration Microservices

**Contexte :**
L'entreprise "TechCorp" migre son application monolithique vers des microservices sur Kubernetes. Ils ont besoin d'exposer 3 services distincts sous un seul nom de domaine, mais avec des règles de routage précises.

**Tes contraintes d'Architecte :**
* Tout doit être créé dans un **Namespace isolé** (pas dans `default`).
* Tu dois gérer un problème de "conflit de chemin" (Path Rewrite).
* Tu dois gérer des ports de services non-standards (Trap classique CKA).

---

### 📋 Ticket JIRA #1 : Déploiement des Workloads

**Tâche :** Crée les ressources suivantes dans un Namespace nommé `prod-shop`.

1.  **Frontend (Le Site Web) :**
    * Deployment: `shop-front`, Image: `nginx:alpine`, Replicas: 2.
    * Service: `front-svc`, Port exposé: 80.

2.  **Backend (API de Paiement) :**
    * Deployment: `payment-api`, Image: `httpd:alpine` (Apache).
    * Service: `pay-svc`.
    * **⚠️ Piège CKA :** Le conteneur Apache écoute sur le port **80**, mais l'équipe sécu impose que le Service expose le port **5000** à l'intérieur du cluster.

3.  **Admin (Outil Interne) :**
    * Deployment: `admin-tools`, Image: `nginx:alpine`.
    * Service: `admin-svc`, Port exposé: 8080 (Le conteneur est sur le 80).

---

### 📋 Ticket JIRA #2 : La Règle Ingress Complexe

**Tâche :** Crée un seul Ingress nommé `techcorp-ingress` dans le namespace `prod-shop`.

**Cahier des charges du routage :**
* **Domaine (Host) :** `shop.local`
* **Règle 1 :** Tout trafic vers la racine (`/`) doit aller vers le **Frontend**.
* **Règle 2 :** Tout trafic commençant par `/api/v1` doit aller vers le **Backend (Paiement)**.
    * *Challenge Technique :* L'application Apache (`httpd`) sert ses fichiers à la racine (`/`). Si tu lui envoies une requête `/api/v1/index.html`, elle répondra 404. Tu **dois** réécrire l'URL pour qu'Apache reçoive juste `/`.
* **Règle 3 :** Tout trafic commençant par `/admin` doit aller vers l'**Admin**.

---

### 🧪 Critères de Validation (Ta Check-list Expert)

Pour réussir le challenge, tu dois pouvoir exécuter ces commandes depuis ton Bastion (en utilisant ton IP Node et le port NodePort que tu as configuré, ex: `30729`) et obtenir les bons résultats.

1.  **Test Frontend :**
    `curl -H "Host: shop.local" http://10.0.1.6:30729/`
    ➔ Doit répondre : `Welcome to nginx!`

2.  **Test API (Le test critique) :**
    `curl -H "Host: shop.local" http://10.0.1.6:30729/api/v1/`
    ➔ Doit répondre : `It works!` (C'est la page par défaut de l'image httpd).
    *Si tu as une 404 ici, c'est que ton annotation de Rewrite est fausse.*

3.  **Test Admin :**
    `curl -H "Host: shop.local" http://10.0.1.6:30729/admin/`
    ➔ Doit répondre : `Welcome to nginx!` (Note : ici aussi, il faudra peut-être une réécriture si l'admin attend la racine).
