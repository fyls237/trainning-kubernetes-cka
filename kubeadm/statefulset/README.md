# 🔐 StatefulSet - Guide Complet CKA

## 🎯 StatefulSet vs Deployment

La distinction entre **Deployment** et **StatefulSet** est un classique de la CKA. Voici la différence clé :

| Aspect | Deployment | StatefulSet |
|--------|-----------|-----------|
| **Identité des Pods** | Éphémère (noms aléatoires) | Stable (web-0, web-1, web-2) |
| **Ordre de démarrage** | Parallèle | Séquentiel |
| **Networking** | Load balancer aléatoire | Stable DNS (web-0.nginx.default) |
| **Storage** | Partagé entre replicas | Une PVC par replica |
| **Cas d'usage** | Apps stateless | BD, caches, queues |

### Quand utiliser StatefulSet ?

✅ **Utilisez StatefulSet pour :**
- **Bases de données** : MySQL, PostgreSQL, MongoDB
- **Caches** : Redis cluster, Memcached
- **Queues** : RabbitMQ, Kafka
- **Clouds distribués** : Cassandra, Elasticsearch
- Tout ce qui a besoin d'une identité stable

❌ **N'utilisez PAS StatefulSet pour :**
- Apps web stateless (Nginx, Apache)
- APIs stateless (Node.js, Python)
- Celles qui peuvent être déployées en parallèle

---

## 🏗️ Anatomie d'un StatefulSet

**Fichier exemple : nginx StatefulSet**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec: 
  # ⭐ CLÉS ABSOLUES
  serviceName: "nginx"          # Service headless REQUIS
  selector:
    matchLabels:
      app: nginx
  
  # Configuration
  replicas: 3
  minReadySeconds: 10
  
  # Template du Pod
  template:
    metadata:
      labels: 
        app: nginx
    spec: 
      terminationGracePeriodSeconds: 10  # Temps arrêt gracieux
      containers:
      - name: nginx
        image: registry.k8s.io/nginx-slim:0.24
        ports: 
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  
  # ⭐ CLÉS ABSOLUES : PVC par Pod
  volumeClaimTemplates:
  - metadata:
      name: www
    spec: 
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "nginx-storage-class"
      resources:
        requests:
          storage: 1Gi
```

---

## 🔗 Les 3 Composants du StatefulSet

### 1️⃣ Headless Service - L'Identité Stable

**Fichier exemple : `service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None              # ← CLÉS : Headless = pas de ClusterIP
  selector:
    app: nginx
```

**Pourquoi Headless ?**

- `clusterIP: None` crée un **DNS stable** pour chaque pod
- Les pods sont accessibles via :
  - `web-0.nginx.default.svc.cluster.local` (Pod 0)
  - `web-1.nginx.default.svc.cluster.local` (Pod 1)
  - `web-2.nginx.default.svc.cluster.local` (Pod 2)

**Sans Headless :**
- DNS aléatoire, identités instables
- Impossible de connaître l'ordre des pods
- Problématique pour les clusters distribués

**Test DNS :**
```bash
# Accéder au pod 0 spécifiquement
kubectl run -it --rm debug --image=alpine -- sh
# nslookup web-0.nginx.default.svc.cluster.local
```

---

### 2️⃣ StorageClass - Le Template de Storage

**Fichier exemple : `storage-class.yaml`**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nginx-storage-class
provisioner: file.csi.azure.com  # ← Azure File CSI
parameters:
  secretName: azure-storage-secret
  secretNamespace: kube-system
  storageAccount: k8ssvc
  skuName: Standard_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer  # ← Important
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=0
  - gid=0
  - mfsymlinks
  - cache=strict
  - nosharesock
```

**Paramètres clés :**

| Paramètre | Signification | Impact |
|-----------|--------------|--------|
| **provisioner** | Backend de storage | `file.csi.azure.com` (Azure), `pd.csi.storage.gke.io` (GCP) |
| **volumeBindingMode** | Quand créer le PV | `Immediate` (rapide), `WaitForFirstConsumer` (après pod) |
| **reclaimPolicy** | Après suppression | `Delete`, `Retain` |
| **allowVolumeExpansion** | Agrandir ? | `true`, `false` |

---

### 3️⃣ volumeClaimTemplates - Une PVC par Pod

```yaml
volumeClaimTemplates:
- metadata:
    name: www                    # ← Nom de la PVC
  spec: 
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: "nginx-storage-class"
    resources:
      requests:
        storage: 1Gi
```

**Ce que ça crée :**

Automatiquement, Kubernetes crée :
- **Pod web-0** → **PVC www-web-0** → **PV web-0**
- **Pod web-1** → **PVC www-web-1** → **PV web-1**
- **Pod web-2** → **PVC www-web-2** → **PV web-2**

**Chaque pod a son propre storage** ! C'est ça qui distingue un StatefulSet.

```bash
# Vérifier les PVCs créées
kubectl get pvc
# www-web-0   Bound    pv-web-0   1Gi
# www-web-1   Bound    pv-web-1   1Gi
# www-web-2   Bound    pv-web-2   1Gi
```

---

## 🚀 Déploiement et Opérations StatefulSet

### Créer un StatefulSet

```bash
# 1. Créer la StorageClass
kubectl apply -f storage-class.yaml

# 2. Créer le Service Headless (OBLIGATOIRE)
kubectl apply -f service.yaml

# 3. Créer le StatefulSet
kubectl apply -f statefulset.yaml

# 4. Vérifier
kubectl get statefulset
kubectl get pods -o wide
kubectl get pvc
```

### Vérifier l'Ordre de Démarrage

```bash
# Les pods démarrent SÉQUENTIELLEMENT
kubectl get pods --watch
# web-0 en train de démarrer
# web-0 prêt
# web-1 en train de démarrer
# web-1 prêt
# web-2 en train de démarrer
# web-2 prêt
```

### Vérifier les Identités Stables

```bash
# Les noms sont prévisibles
kubectl get pods
# web-0   Running
# web-1   Running
# web-2   Running

# Les DNS sont stables
kubectl run -it --rm debug --image=alpine -- sh
# nslookup web-0.nginx.default.svc.cluster.local
# nslookup web-1.nginx.default.svc.cluster.local
# nslookup web-2.nginx.default.svc.cluster.local
```

### Vérifier le Storage Stable

```bash
# Chaque pod a sa PVC
kubectl get pvc
# www-web-0   Bound    pv-web-0   1Gi
# www-web-1   Bound    pv-web-1   1Gi
# www-web-2   Bound    pv-web-2   1Gi

# Même si le pod redémarre, il récupère sa PVC
kubectl delete pod web-0
# web-0 recréé avec la même PVC (www-web-0)
```

---

## 🔴 Troubleshooting StatefulSet - CKA

### ❌ Pods ne Démarrent pas en Ordre

**Symptôme :**
```bash
kubectl get pods
# web-0   Pending
# web-1   Running   ← Devrait pas démarrer !
# web-2   Running   ← Devrait pas démarrer !
```

**Causes :**
- PVC pas créée pour web-0
- StorageClass absent ou misconfigured
- Pod web-0 en erreur (CrashLoop)

**Solutions :**
```bash
# 1. Vérifier les PVCs
kubectl get pvc
# www-web-0 doit exister et être Bound

# 2. Vérifier la StorageClass
kubectl get storageclass nginx-storage-class

# 3. Vérifier les événements
kubectl describe pod web-0
kubectl describe pvc www-web-0

# 4. Vérifier le provisioner
kubectl get sc nginx-storage-class -o yaml | grep provisioner
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : StorageClass absent
volumeClaimTemplates:
- metadata:
    name: www
  spec: 
    storageClassName: "non-existent-sc"  # ← SC n'existe pas !

---
# ✅ CORRECT
kubectl apply -f storage-class.yaml  # Créer d'abord
kubectl apply -f statefulset.yaml    # Puis StatefulSet
```

---

### ❌ Service Headless Manquant

**Symptôme :**
```bash
kubectl describe statefulset web
# ... Events: ... serviceName: "nginx" not found
```

**Cause :**
Le StatefulSet référence un Service qui n'existe pas.

**Solution :**
```bash
# 1. Vérifier que le Service existe
kubectl get svc nginx

# 2. Vérifier que c'est un Headless (clusterIP: None)
kubectl get svc nginx -o yaml | grep clusterIP
# clusterIP: None

# 3. Créer le Service s'il manque
kubectl apply -f service.yaml
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : Service pas Headless
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - port: 80
  # ← Manque clusterIP: None !

---
# ✅ CORRECT
spec:
  clusterIP: None    # ← Obligatoire
  selector:
    app: nginx
```

---

### ❌ Pods Stuck in Pending

**Symptôme :**
```bash
kubectl describe pod web-0
# Events: ... 0/3 nodes available: 3 Insufficient memory
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Ressources insuffisantes** | `kubectl describe node` | Réduire requests ou ajouter nœuds |
| **PVC Pending** | `kubectl get pvc` | Vérifier StorageClass |
| **Affinity impossible** | Pod demande affinity non satisfiable | Ajuster affinity |
| **Taint incompatible** | `kubectl describe node` → Taints | Ajouter tolérances |

**Diagnostic complet :**
```bash
# 1. Vérifier le pod
kubectl describe pod web-0

# 2. Vérifier la PVC
kubectl describe pvc www-web-0

# 3. Vérifier les nœuds
kubectl describe nodes

# 4. Vérifier les événements
kubectl get events --sort-by='.lastTimestamp' | tail -20

# 5. Vérifier les logs du pod
kubectl logs web-0
```

---

### ❌ PVC pas Créée Automatiquement

**Symptôme :**
```bash
kubectl get pvc
# (aucune PVC pour le StatefulSet)
```

**Cause :**
- `volumeClaimTemplates` mal configuré
- StorageClass invalide
- StatefulSet pas crée correctement

**Solution :**
```bash
# 1. Vérifier volumeClaimTemplates dans le StatefulSet
kubectl get statefulset web -o yaml | grep -A 10 "volumeClaimTemplates"

# 2. Vérifier la StorageClass
kubectl get sc nginx-storage-class

# 3. Redéployer le StatefulSet
kubectl delete statefulset web
kubectl apply -f statefulset.yaml
```

---

### ❌ Supprimer un StatefulSet (Attention !)

**Symptôme :**
```bash
kubectl delete statefulset web
# StatefulSet supprimé mais les Pods restent ?
```

**Comportement par défaut :**

Kubernetes peut laisser les Pods orphelins pour éviter les pertes de données.

**Pour supprimer complètement :**
```bash
# Option 1 : Supprimer avec les Pods (CASCADE)
kubectl delete statefulset web --cascade=foreground
kubectl delete statefulset web --cascade=background

# Option 2 : Supprimer d'abord les replicas
kubectl scale statefulset web --replicas=0
kubectl delete statefulset web

# Option 3 : Supprimer tout (StatefulSet + Pods + PVCs)
kubectl delete statefulset web --cascade=foreground
kubectl delete pvc www-web-0 www-web-1 www-web-2
```

**⚠️ Attention :** Les PVCs ne sont pas supprimées automatiquement !

---

## 📊 Ordre de Démarrage vs Arrêt

### Démarrage (Ordinal croissant)

```
StatefulSet créé
    ↓
web-0 créé
    ↓
web-0 Running + Ready
    ↓
web-1 créé
    ↓
web-1 Running + Ready
    ↓
web-2 créé
    ↓
web-2 Running + Ready
```

### Arrêt (Ordinal décroissant)

```
kubectl delete statefulset web
    ↓
web-2 supprimé en premier
    ↓
web-1 supprimé
    ↓
web-0 supprimé en dernier
```

**Pourquoi cet ordre ?**

Pour les BDs distribuées (ex: MySQL cluster) :
- Démarrage : du master aux slaves
- Arrêt : des slaves au master
- Évite la corruption des données

---

## 📝 Checklist Rapide CKA

```bash
# Étape 1 : Vérifier le Service Headless
kubectl get svc
kubectl get svc <name> -o yaml | grep clusterIP

# Étape 2 : Vérifier la StorageClass
kubectl get sc
kubectl describe sc <name>

# Étape 3 : Vérifier les PVCs
kubectl get pvc
kubectl describe pvc www-web-0

# Étape 4 : Vérifier les Pods
kubectl get statefulset
kubectl get pods -o wide

# Étape 5 : Vérifier l'ordre
kubectl get pods --sort-by=.metadata.name

# Étape 6 : Vérifier le DNS stable
kubectl run -it --rm debug --image=alpine -- sh
# nslookup web-0.nginx.default.svc.cluster.local

# Étape 7 : Vérifier les logs
kubectl logs web-0
kubectl describe pod web-0
```

---

## 🎯 Patterns CKA StatefulSet

### Pattern 1 : StatefulSet Basique (Nginx)

```yaml
# 1. Headless Service
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
  - port: 80

---
# 2. StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      storageClassName: "fast-ssd"
      resources:
        requests:
          storage: 1Gi
```

### Pattern 2 : StatefulSet MySQL (Avec Init)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql"
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
      - name: init-mysql
        image: mysql:8.0
        command: ["sh", "-c", "mysql_install_db --user=mysql"]
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
      
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: "mysql-storage"
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

### Pattern 3 : StatefulSet avec Cassandra

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
spec:
  serviceName: cassandra
  replicas: 3
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - cassandra
            topologyKey: kubernetes.io/hostname
      
      containers:
      - name: cassandra
        image: cassandra:latest
        volumeMounts:
        - name: cassandra-data
          mountPath: /var/lib/cassandra
  
  volumeClaimTemplates:
  - metadata:
      name: cassandra-data
    spec:
      storageClassName: "fast-ssd"
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```

---

## 📖 Références Officielles

- [StatefulSet Official Docs](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)
- [volumeClaimTemplates](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates)

---

## 💡 Tips d'Examen CKA

✅ **Ordre de création :**
```bash
1. StorageClass
2. Service Headless (clusterIP: None)
3. StatefulSet
```

✅ **Points à retenir :**
- Identité stable : web-0, web-1, web-2
- DNS stable : web-0.nginx.default.svc.cluster.local
- Une PVC par Pod (créée automatiquement)
- Démarrage séquentiel, arrêt inverse

✅ **Erreur classique CKA :**
```yaml
# ❌ OUBLIER serviceName
spec:
  # serviceName: "nginx"  ← Oublié !

# ✅ CORRECT
spec:
  serviceName: "nginx"
```

✅ **Vérifier rapidement :**
```bash
# Identité stable ?
kubectl get pods
# web-0, web-1, web-2 ✓

# DNS stable ?
kubectl run -it --rm debug --image=alpine -- sh
nslookup web-0.nginx.default.svc.cluster.local

# PVCs créées ?
kubectl get pvc
# www-web-0, www-web-1, www-web-2 ✓
```
