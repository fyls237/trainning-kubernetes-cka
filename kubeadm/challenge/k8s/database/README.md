# 💾 Persistance des Données & Base de Données (PostgreSQL / Redis)

Ce dossier documente l'architecture de stockage et de données de notre application Portfolio.
C'est un exemple concret de gestion de **Stateful Applications** dans Kubernetes on-premise (ou VM non-managées).

---

## 🛑 Le Challenge initial : Stockage Cloud vs Base de Données

Initialement, nous avons tenté d'utiliser **Azure Files (SMB/CIFS)** pour stocker les données de PostgreSQL.
**C'était une erreur.** Les bases de données relationnelles comme Postgres ont besoin d'un système de fichiers POSIX strict pour gérer le verrouillage des fichiers ("File Locking").
*   **Symptôme** : Postgres crashait en boucle ou corrompait les données.
*   **Leçon** : Ne jamais utiliser SMB/Azure Files pour une base de données. Préférez Block Storage (Disk) ou NFS fiable.

---

## 🛠️ La Solution : Dynamic Provisioning avec NFS

Pour contourner ce problème et apprendre le **Dynamic Provisioning**, nous avons monté notre propre serveur NFS au sein du cluster.

### 1. Architecture du Stockage
*   **Infrastructure** : Le nœud `k8s-worker-1` dispose d'un disque de données dédié (`/dev/sdc` monté sur `/mnt/k8s-db-data`).
*   **Serveur NFS** : Installé sur ce même nœud worker.
*   **Kubernetes** : Un "Provisioner" automatique crée des dossiers à la volée sur ce serveur NFS chaque fois qu'un Pod demande de l'espace (PVC).

### 2. Installation du Serveur NFS (Côté Linux)
Sur le nœud qui héberge les données (`k8s-worker-1`) :
```bash
# Installation
sudo apt-get update
sudo apt-get install nfs-kernel-server

# Configuration de l'export (/etc/exports)
/mnt/k8s-db-data *(rw,sync,no_subtree_check,no_root_squash)

# Application
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

**Point Critique ⚠️** : Configuration du `/etc/fstab` avec l'UUID du disque pour éviter que le montage échoue si le nom du disque change (sda/sdc) au reboot.

### 3. Configuration des Clients
Sur **TOUS** les nœuds (Master + Workers) :
```bash
sudo apt-get install nfs-common
```
*Sans cela, les Pods resteront bloqués en `ContainerCreating` car le Kubelet ne saura pas monter du NFS.*

### 4. Le Dynamic Provisioner (Côté Kubernetes)
Nous avons déployé `nfs-subdir-external-provisioner` via Helm.
Cela a créé une **StorageClass** nommée `nfs-client`.

*   **Avant (Statique)** : L'admin doit créer manuellement un PV de 10Go, puis le Dev un PVC.
*   **Maintenant (Dynamique)** : Le Dev crée un PVC (`storageClassName: nfs-client`), et le Provisioner crée tout seul le PV et le dossier correspondant sur le disque physique.

---

## 🐘 PostgreSQL (StatefulSet)

Nous utilisons un **StatefulSet** et non un Deployment.
Pourquoi ?
1.  **Identité stable** : Le Pod s'appelle toujours `postgres-0`, pas `postgres-randomhash`.
2.  **Volume Stable** : Si le Pod redémarre, il recupère EXACTEMENT le même disque (`pgdata-postgres-0`).

**Manifestes :** Dans `k8s/database/postgres/`.

---

## ⚡ Redis (Cache)

Utilisé pour mettre en cache les requêtes de lecture (`GET /projects`).
Déployé également en StatefulSet pour la persistance (optionnel pour du cache, mais bonne pratique).

**Manifestes :** Dans `k8s/database/redis/`.

---

## 🔒 Gestion des Secrets (Sealed Secrets)

Les mots de passe de PostgreSQL et Redis ne doivent **jamais** être stockés en clair dans Git.
Nous utilisons **Sealed Secrets** (`bitnami.com/v1alpha1`) pour chiffrer les secrets avec la clé publique du cluster.

### Architecture des secrets

```
database/
├── postgres/
│   ├── secret.yaml          ← Secret en clair (⚠️  NE PAS committer !)
│   └── secret-sealed.yaml   ← Secret chiffré (✅ Sûr pour Git)
└── redis/
    ├── secret.yaml          ← Secret en clair (⚠️  NE PAS committer !)
    └── secret-sealed.yaml   ← Secret chiffré (✅ Sûr pour Git)
```

### 📦 PostgreSQL Secret (`postgres-secret`)

Le secret expose une clé `password` injectée dans le StatefulSet PostgreSQL et dans toute ressource qui en a besoin (backend, CronJob de backup).

```yaml
# secret.yaml (version lisible, usage local uniquement)
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: prod-database
type: Opaque
data:
  password: cG9zdGdyZXBhc3M=   # base64("postgrepass")
```

```yaml
# secret-sealed.yaml (version chiffrée, prête pour GitOps)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: postgres-secret
  namespace: prod-database
spec:
  encryptedData:
    password: <valeur chiffrée par kubeseal>
```

### ⚡ Redis Secret (`redis-secret`)

Même principe : une clé `password` utilisée par le StatefulSet Redis.

```yaml
# secret.yaml (version lisible, usage local uniquement)
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: prod-database
type: Opaque
data:
  password: cmVkaXNwYXNz   # base64("redispass")
```

### 🚀 Workflow GitOps

**Générer un secret chiffré avec kubeseal :**
```bash
# 1. Récupérer la clé publique du cluster (une seule fois)
kubeseal --fetch-cert --controller-namespace kube-system > pub-cert.pem

# 2. Chiffrer le secret
kubeseal --cert pub-cert.pem --format yaml < secret.yaml > secret-sealed.yaml

# 3. Committer uniquement le fichier sealed
git add secret-sealed.yaml
git commit -m "feat: add sealed secret for postgres"
# ⛔ git add secret.yaml  ← NE JAMAIS FAIRE
```

**Déployer les secrets sur le cluster :**
```bash
# Les SealedSecrets sont auto-déchiffrés par le controller au moment de l'apply
kubectl apply -f postgres/secret-sealed.yaml
kubectl apply -f redis/secret-sealed.yaml

# Vérifier que le Secret a bien été créé par le controller
kubectl get secret postgres-secret -n prod-database
kubectl get secret redis-secret -n prod-database
```

**Modifier un secret existant :**
```bash
# 1. Modifier secret.yaml localement
# 2. Rechiffrer
kubeseal --cert pub-cert.pem --format yaml < secret.yaml > secret-sealed.yaml
# 3. Appliquer
kubectl apply -f secret-sealed.yaml
```

> **Point Clé** : Un SealedSecret est lié au **namespace + nom** du secret cible. Si vous changez le nom ou le namespace, vous devez rechiffrer.

---

## 🎓 Résumé des Commandes

Si vous devez remonter l'infra stockage :

1.  Vérifier que le NFS tourne sur le worker :
    `systemctl status nfs-kernel-server`
2.  Vérifier que la StorageClass est là :
    `kubectl get sc`
3.  Déployer les Bases de Données :
    ```bash
    kubectl apply -f k8s/database/namespace.yaml
    # Sealed Secrets en premier (les StatefulSets en ont besoin)
    kubectl apply -f k8s/database/postgres/secret-sealed.yaml
    kubectl apply -f k8s/database/redis/secret-sealed.yaml
    # Puis les ressources
    kubectl apply -f k8s/database/postgres/
    kubectl apply -f k8s/database/redis/
    ```
