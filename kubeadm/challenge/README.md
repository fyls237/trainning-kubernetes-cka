# 🦅 Projet Phoenix : Architecture Kubernetes E-commerce

Ce projet vise à déployer une architecture micro-services complète, résiliente et sécurisée sur un cluster Kubernetes (Kubeadm/Azure), en suivant les meilleures pratiques DevOps et les exigences de la certification CKA.

## 🏗️ Architecture Technique

Le projet est divisé en 4 couches logiques :

### 💾 Phase 1 : Fondations & Données (Stateful)

**Objectif :** Mettre en place la couche de persistance durable.

* **Storage :** Utilisation de StorageClass (Azure Files/Disk) pour le provisionnement dynamique.
* **Base de données :** Déploiement de **PostgreSQL** via un `StatefulSet`.
* **Cache :** Déploiement de **Redis** via un `StatefulSet`.
* **Réseau interne :** Configuration de Services `Headless` pour la découverte DNS stable des pods de données.

### ⚙️ Phase 2 : Logique Applicative (Stateless)

**Objectif :** Déployer les applications qui consomment les données.

* **Backend API :** Déploiement (Deployment) d'une API (Python/Go) simulée.
* **Frontend :** Déploiement (Deployment) d'un serveur Nginx.
* **Configuration :**
* `ConfigMap` pour les fichiers de config Nginx et les variables d'environnement non sensibles.
* `Secret` pour les identifiants de la base de données (encodés en base64).


* **Services :** Exposition interne via `ClusterIP`.

### 🔒 Phase 3 : Exposition & Sécurité

**Objectif :** Sécuriser et exposer l'application au monde.

* **Ingress Controller :** Configuration de Nginx Ingress pour router le trafic HTTP.
* **Ingress Resource :** Règles de routage basées sur le host (ex: `shop.phoenix.local`).
* **Network Policies :**
* Politique "Default Deny" (Tout interdire par défaut).
* Règles spécifiques pour autoriser : Ingress -> Front -> Back -> DB.



### 📈 Phase 4 : Robustesse & Opérations (Day-2 Ops)

**Objectif :** Garantir la tenue à la charge et la maintenance.

* **Autoscaling (HPA) :** Configuration du scaling automatique du Backend basé sur l'utilisation CPU.
* **Maintenance :** Création d'un `CronJob` pour simuler une sauvegarde de la base de données chaque nuit.
* **Observabilité :** Déploiement d'un `DaemonSet` en installent `Prometheus`, `Grafana` et `Loki` 
