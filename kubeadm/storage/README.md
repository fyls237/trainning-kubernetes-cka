# 💾 Storage & Persistence - Guide Complet CKA

## 🎯 Concepts Fondamentaux

Le storage dans Kubernetes répond à une problématique majeure : **les containers sont éphémères**. Si un pod crash, ses données disparaissent. C'est pour ça qu'on a besoin de :

- **Volumes** : Stockage attaché à un Pod
- **PersistentVolumes (PV)** : Ressource cluster abstraite
- **PersistentVolumeClaims (PVC)** : Demande de stockage par un Pod
- **StorageClasses** : Classe de stockage (NFS, ceph, iSCSI, cloud, etc.)

---

## 📊 Architecture du Storage dans Kubernetes

```
┌─────────────────────────────────────────────┐
│           StorageClass                      │  Définit LE TYPE de storage
│  (nfs-csi, fast-ssd, azure-file, etc.)     │
└─────────────┬───────────────────────────────┘
              │
              ↓ Provisionne
┌─────────────────────────────────────────────┐
│      PersistentVolume (PV)                  │  Ressource réelle du cluster
│  (5Gi NFS @ 4.233.111.136:/data)           │
└─────────────┬───────────────────────────────┘
              │
              ↓ Bound to
┌─────────────────────────────────────────────┐
│    PersistentVolumeClaim (PVC)              │  Demande du Pod
│    (5Gi ReadWriteMany)                      │
└─────────────┬───────────────────────────────┘
              │
              ↓ Mounted by
┌─────────────────────────────────────────────┐
│           Pod/Deployment                    │  Utilise le volume
│    /var/www/html → /data (NFS mount)       │
└─────────────────────────────────────────────┘
```

---

## 🔧 Les 3 Composants Clés

### 1️⃣ StorageClass - La Fabrique de Volumes

**Fichier exemple : `storageclass-nfs.yaml`**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: 
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: 4.233.111.136    # ← Serveur NFS
  share: /data             # ← Chemin NFS
reclaimPolicy: Delete      # ← Supprimer le PV après PVC delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
  - nfsvers=4.1           # ← Version NFS
```

**Paramètres clés :**

| Paramètre | Signification | Exemple CKA |
|-----------|--------------|------------|
| **provisioner** | Backend de storage | `nfs.csi.k8s.io`, `pd.csi.storage.gke.io` |
| **reclaimPolicy** | Action après suppression PVC | `Delete`, `Retain`, `Recycle` |
| **volumeBindingMode** | Quand binder le PV | `Immediate`, `WaitForFirstConsumer` |
| **allowVolumeExpansion** | Agrandir la taille ? | `true`, `false` |
| **parameters** | Config spécifique au provisioner | `server`, `share`, `size`, etc. |

**Cas d'usage CKA :**
```bash
# Lister les StorageClasses
kubectl get storageclass

# Voir les détails
kubectl describe storageclass nfs-csi

# Créer une SC simple (sans external provisioner)
kubectl create storageclass fast-ssd \
  --provisioner=kubernetes.io/host-path \
  --parameters=type=fast-ssd
```

---

### 2️⃣ PersistentVolumeClaim (PVC) - La Demande de Storage

**Fichier exemple : `pvc-nfs.yaml`**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs
spec:
  accessModes:
    - ReadWriteMany         # ← RWMany = plusieurs pods peuvent écrire
  resources: 
    requests: 
      storage: 5Gi          # ← 5 Gigabytes
  storageClassName: nfs-csi # ← Utilise la StorageClass nfs-csi
```

**AccessModes - Les 3 Types :**

| Mode | Signification | Cas d'usage |
|------|---------------|-----------|
| **ReadWriteOnce (RWO)** | 1 pod, lecture/écriture | Base de données, single-instance |
| **ReadOnlyMany (ROX)** | Plusieurs pods, lecture seule | Config partagée, assets statiques |
| **ReadWriteMany (RWX)** | Plusieurs pods, lecture/écriture | NFS, CephFS, Azure Files |

⚠️ **Attention CKA :**
- **Block Storage** (EBS, vSAN) : Seulement RWO
- **File Storage** (NFS, SMB) : Supporte RWX
- **Object Storage** (S3) : ReadOnlyMany ou aucun

**Cas d'usage CKA :**
```bash
# Créer une PVC
kubectl apply -f pvc-nfs.yaml

# Voir les PVCs
kubectl get pvc

# Voir les détails et le binding
kubectl describe pvc pvc-nfs

# Vérifier les PVs associés
kubectl get pv
```

---

### 3️⃣ PersistentVolume (PV) - La Ressource Réelle

**Création automatique (Dynamic Provisioning) :**
Quand vous créez une PVC, Kubernetes crée automatiquement un PV si une SC le permet.

**Création manuelle (Static Provisioning) :**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs-manual
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 4.233.111.136
    path: /data
  claimRef:
    namespace: default
    name: pvc-nfs      # ← Bind à cette PVC
```

**États d'un PV :**

| État | Signification | Problème ? |
|------|---------------|-----------|
| **Available** | Pas utilisé, prêt à être claimé | Normal |
| **Bound** | Attaché à une PVC | Normal |
| **Released** | PVC supprimée, PV libéré | Vérifier reclaimPolicy |
| **Failed** | Erreur de montage ou configuration | ❌ À fixer |

---

## 🚀 Patterns CKA : Déploiement avec Storage

### Pattern 1 : Deployment avec PVC (WordPress)

**Fichier exemple : Déploiement WordPress + MySQL**

```yaml
---
# 1. StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: 
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: 4.233.111.136
  share: /data
---
# 2. PVC pour WordPress
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources: 
    requests: 
      storage: 10Gi
  storageClassName: nfs-csi
---
# 3. Deployment WordPress
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels: 
    app: wordpress
spec: 
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  strategy:
    type: Recreate  # ← Important : 1 seul pod à la fois (RWO)
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
      - image: wordpress:6.2.1-apache
        name: wordpress
        env: 
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pvc
```

**Points clés :**
- `strategy: type: Recreate` : Nécessaire pour RWO (1 pod à la fois)
- `volumeMounts.mountPath` : Où monter dans le container
- `volumes.persistentVolumeClaim.claimName` : Lier à la PVC

---

### Pattern 2 : StatefulSet avec Storage (MySQL)

**Fichier exemple : MySQL avec InitContainer cleanup**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
    tier: mysql
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: mysql
  strategy:              
    type: Recreate       # ← RWO = 1 pod à la fois
  template:              
    metadata:
      labels:
        app: wordpress
        tier: mysql
    spec:
      # ✅ InitContainer : Nettoyer les données avant démarrage
      initContainers:
      - name: cleanup-mysql-data
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          set -x
          echo "🧹 Nettoyage du répertoire MySQL..."
          if [ -d "/var/lib/mysql" ]; then
            cd /var/lib/mysql
            find . -mindepth 1 -delete
            echo "✅ Répertoire vidé"
          fi
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: "/var/lib/mysql/"
      
      containers: 
      - image: mysql:8.0
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-root-pass
              key: password
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        - name: MYSQL_DATABASE
          value: wordpress
        - name: MYSQL_USER
          value: wordpress
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: "/var/lib/mysql/"
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

**Points clés :**
- **InitContainer** : Exécuté avant les containers principaux
- Utile pour initialiser/nettoyer les données
- Le cleanup est important pour les BD (évite les corruptions)

---

## 🔴 Troubleshooting Storage - CKA

### ❌ PVC Stuck in Pending

**Symptôme :**
```bash
kubectl get pvc
# PVC        STATUS    VOLUME   CAPACITY
# pvc-nfs    Pending             
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **StorageClass n'existe pas** | `kubectl get storageclass` → Pas nfs-csi | Créer la SC ou corriger le nom dans PVC |
| **Provisioner absent** | `kubectl describe pvc` → "no provisioner found" | Installer le CSI driver (ex: nfs-csi) |
| **NFS serveur inaccessible** | `kubectl describe pvc` → "failed to mount" | Vérifier IP/port NFS, firewall |
| **Pas d'espace disponible** | Disque plein sur le NFS | Libérer de l'espace ou augmenter la storage |
| **AccessMode incompatible** | RWX demandé mais storage ne supporte que RWO | Utiliser RWO ou changer le storage |

**Diagnostic complet :**
```bash
# 1. Vérifier l'existence de la SC
kubectl get storageclass
kubectl describe storageclass nfs-csi

# 2. Voir les détails de la PVC
kubectl describe pvc pvc-nfs

# 3. Vérifier les événements
kubectl get events --sort-by='.lastTimestamp' | grep pvc-nfs

# 4. Vérifier les PVs
kubectl get pv

# 5. Tester la connectivité NFS (si applicable)
kubectl run -it --rm debug --image=alpine -- sh
# Dans le pod: apk add nfs-utils && mount -t nfs 4.233.111.136:/data /mnt
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : PVC reste Pending
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs
spec:
  accessModes:
    - ReadWriteMany
  resources: 
    requests: 
      storage: 5Gi
  storageClassName: non-existent-sc  # ← SC n'existe pas !

---
# ✅ CORRECT : Créer la SC d'abord
kubectl apply -f storageclass-nfs.yaml
kubectl apply -f pvc-nfs.yaml
```

---

### ❌ Pod Stuck in ContainerCreating

**Symptôme :**
```bash
kubectl get pods
# POD              STATUS              
# wordpress        ContainerCreating    (Plus de 30 secondes...)
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **PVC pas Bound** | `kubectl get pvc` → STATUS != Bound | Voir section PVC Pending |
| **Mount échoue** | `kubectl describe pod` → "failed to mount" | Vérifier NFS, permissions, format du path |
| **Pod attendant PVC d'une autre NS** | PVC et Pod dans des namespaces différents | Créer PVC dans le même namespace |
| **Liveness probe échoue immédiatement** | Container démarre mais probe échoue | Ajouter `initialDelaySeconds` |

**Diagnostic complet :**
```bash
# 1. Vérifier l'état du pod
kubectl describe pod wordpress

# 2. Voir les événements
kubectl get events --sort-by='.lastTimestamp' | tail -20

# 3. Vérifier le binding PVC
kubectl get pvc
kubectl describe pvc wp-pvc

# 4. Vérifier les logs du container (s'il démarre)
kubectl logs wordpress -c wordpress

# 5. Entrer dans le pod pour déboguer
kubectl exec -it wordpress -- bash
# Dans le pod: df -h  (voir les mounts)
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : Pod et PVC dans des namespaces différents
apiVersion: v1
kind: Namespace
metadata:
  name: app

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pvc
  namespace: default       # ← PVC dans default
spec:
  storageClassName: nfs-csi
  resources:
    requests:
      storage: 10Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: app           # ← Pod dans app !
spec:
  template:
    spec:
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: wp-pvc  # ← Cherche dans namespace app, pas trouvé !

---
# ✅ CORRECT : Même namespace partout
metadata:
  namespace: app
```

---

### ❌ PV/PVC pas Libérés (Leaking)

**Symptôme :**
```bash
kubectl get pvc
# pvc-old    Bound     pv-old    5Gi

kubectl delete pvc pvc-old
# PVC supprimée mais toujours là !
```

**Cause :**
```bash
kubectl get pvc
# pvc-old stays with finalizers
kubectl describe pvc pvc-old | grep finalizers
# kubernetes.io/pvc-protection
```

**Solution :**
```bash
# 1. Vérifier les pods utilisant la PVC
kubectl get pods -o json | grep pvc-old

# 2. Supprimer le finalizer (dernier recours)
kubectl patch pvc pvc-old -p '{"metadata":{"finalizers":null}}'

# 3. Vérifier le reclaimPolicy du PV
kubectl get pv
kubectl describe pv pv-old | grep reclaimPolicy
# Si "Retain", le PV reste. Options : Delete, Recycle, Retain
```

---

### ❌ Data Corruption ou Données Perdues

**Scénario courant CKA :**
```bash
# Déploiement MySQL
kubectl apply -f mysql-deployment.yaml

# Plus tard, recréation du pod
kubectl delete pod mysql-abc123

# Données MySQL corrompues ou perdues
```

**Cause :** MySQL recrée les fichiers de la BD, mais l'ancien état reste.

**Solution (Pattern utilisé) :**

```yaml
initContainers:
- name: cleanup-mysql-data
  image: busybox:latest
  command:
  - sh
  - -c
  - |
    if [ -d "/var/lib/mysql" ]; then
      cd /var/lib/mysql
      find . -mindepth 1 -delete
      echo "✅ Cleanup done"
    fi
  volumeMounts:
  - name: mysql-persistent-storage
    mountPath: "/var/lib/mysql/"
```

**Avantages :**
- ✅ Garantit une BD propre à chaque démarrage
- ✅ Évite les corruptions
- ✅ Idéal pour les labos/tests

**Inconvénient :**
- ❌ Perte des données à chaque redémarrage (acceptable en lab)

---

## 📝 Checklist Rapide CKA

```bash
# Étape 1 : Vérifier les ressources
kubectl get pv,pvc,sc

# Étape 2 : Vérifier les bindings
kubectl get pvc -o wide

# Étape 3 : Vérifier les détails
kubectl describe pvc <name>
kubectl describe pv <name>
kubectl describe sc <name>

# Étape 4 : Vérifier les pods
kubectl get pods -o wide
kubectl describe pod <name>

# Étape 5 : Vérifier les mounts dans le pod
kubectl exec -it <pod> -- df -h
kubectl exec -it <pod> -- ls -la /mount/path

# Étape 6 : Tester la connectivité NFS (si NFS)
kubectl run -it --rm test --image=alpine -- sh
# mount -t nfs server:/path /mnt

# Étape 7 : Vérifier les logs
kubectl logs <pod>
kubectl get events | grep <pod>
```

---

## 📊 Tableau des Volumes vs Storage Persistant

| Type | Durée de Vie | Cas d'usage | Exemple |
|------|-------------|-----------|---------|
| **emptyDir** | Vie du Pod | Cache, temp files | Redis cache |
| **hostPath** | Vie du Node | Config locale | Fichiers de config |
| **NFS** | Infini | Données partagées | WordPress files |
| **Block (EBS)** | Infini | BD | MySQL, PostgreSQL |
| **ConfigMap** | Infini | Config | App config |
| **Secret** | Infini | Credentials | DB password |

---

## 🎯 Patterns CKA à Maîtriser

✅ **Pattern 1 : PVC + Deployment**
```bash
1. Créer StorageClass
2. Créer PVC (référence SC)
3. Créer Deployment (référence PVC dans volumes)
4. Pod utilise PVC via volumeMount
```

✅ **Pattern 2 : InitContainer Cleanup**
```bash
1. InitContainer s'exécute avant les containers
2. Nettoie le répertoire de montage
3. Utile pour les BD stateless
```

✅ **Pattern 3 : Multiple PVCs**
```bash
1. Deployment peut utiliser plusieurs PVCs
2. Chacune montée à un chemin différent
3. Exemple : WordPress (files) + MySQL (BD)
```

✅ **Pattern 4 : StatefulSet**
```bash
1. Utilise volumeClaimTemplates
2. Crée une PVC par replica
3. Chaque pod a son propre stockage
4. Voir le README StatefulSet
```

---

## 📖 Références Officielles

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [StorageClasses](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)

---

## 💡 Tips d'Examen CKA

✅ **Toujours vérifier avant de créer :**
```bash
kubectl get storageclass
kubectl get pvc
kubectl get pv
```

✅ **Vérifier les bindings :**
```bash
kubectl get pvc -o wide
# VOLUME doit être rempli pour un binding réussi
```

✅ **Tester immédiatement :**
```bash
kubectl apply -f pvc.yaml
kubectl get pvc --watch  # Vérifier STATUS = Bound
```

✅ **Debug rapidement :**
```bash
# Image debug légère avec tools
kubectl run -it --rm debug --image=nicolaka/netshoot -- bash
```

✅ **Patterns à mémoriser :**
- SC → PVC → Deployment/StatefulSet
- RWO pour les BD (Recreate strategy)
- RWX pour les fichiers partagés
- InitContainer pour les BDs stateless
