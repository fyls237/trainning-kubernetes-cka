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

## 🎓 Résumé des Commandes

Si vous devez remonter l'infra stockage :

1.  Vérifier que le NFS tourne sur le worker :
    `systemctl status nfs-kernel-server`
2.  Vérifier que la StorageClass est là :
    `kubectl get sc`
3.  Déployer les Bases de Données :
    ```bash
    kubectl apply -f k8s/database/namespace.yaml
    kubectl apply -f k8s/database/postgres/
    kubectl apply -f k8s/database/redis/
    ```
