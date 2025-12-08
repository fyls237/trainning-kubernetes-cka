# 📊 Comparatif Kubernetes Resources - CKA Cheat Sheet

## Vue Rapide : Quelle Ressource Utiliser ?

### 🎯 Par Cas d'Usage

| Cas d'Usage | Ressource | Pourquoi ? |
|-------------|-----------|-----------|
| **Site web stateless (Nginx)** | Deployment | Replicas parallèles, load-balancing simple |
| **API REST sans état** | Deployment | Scalabilité simple, redémarrage transparent |
| **Base de données (MySQL)** | StatefulSet | Identité stable, une PVC par pod |
| **Cache distribué (Redis)** | StatefulSet | DNS stable pour communication inter-pods |
| **Agent système (Prometheus)** | DaemonSet | 1 pod par nœud, même sur control-plane |
| **Logging (Fluentd)** | DaemonSet | Tails logs sur tous les nœuds |
| **Monitoring (Node-exporter)** | DaemonSet | Collecte des métriques de tous les nœuds |
| **Routage HTTP/HTTPS** | Ingress | URL path-based, hostname-based routing |
| **Configuration partagée** | ConfigMap | Données non-sensibles |
| **Passwords/tokens** | Secret | Données sensibles (encodées Base64) |
| **Stockage persistant** | PersistentVolume | Abstraction du storage backend |

---

## 📋 Comparaison Détaillée

### Deployment vs StatefulSet vs DaemonSet

```yaml
# DEPLOYMENT - Apps Stateless
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  strategy:
    type: RollingUpdate  # ← Mise à jour progressive
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        # ← Aucun volume persistant en général
```

**Caractéristiques :**
- ✅ Noms aléatoires : `nginx-abc12`, `nginx-def45`
- ✅ Replicas parallèles
- ✅ Redémarrage transparent (sans perte)
- ❌ Pas d'identité stable

---

```yaml
# STATEFULSET - Apps Stateful (BD)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql-headless"  # ← OBLIGATOIRE
  replicas: 3
  template:
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
  volumeClaimTemplates:         # ← Une PVC par pod
  - metadata:
      name: data
    spec:
      storageClassName: "fast-ssd"
      resources:
        requests:
          storage: 10Gi
```

**Caractéristiques :**
- ✅ Noms ordonnés : `mysql-0`, `mysql-1`, `mysql-2`
- ✅ DNS stables : `mysql-0.mysql-headless.default.svc.cluster.local`
- ✅ Une PVC par pod (créée automatiquement)
- ✅ Démarrage/arrêt séquentiel
- ❌ Plus lent que Deployment

---

```yaml
# DAEMONSET - Agent sur tous les nœuds
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  template:
    spec:
      tolerations:
      - operator: "Exists"  # ← S'exécute même sur master/tainted nodes
      containers:
      - name: exporter
        image: prom/node-exporter:latest
```

**Caractéristiques :**
- ✅ 1 pod par nœud (automatique)
- ✅ S'ajoute auto aux nouveaux nœuds
- ✅ Supporte tolerations pour taints
- ❌ Pas de replicas manuelles

---

### Service Types

```yaml
# ClusterIP (Défaut)
apiVersion: v1
kind: Service
metadata:
  name: internal-service
spec:
  type: ClusterIP        # ← Accessible SEULEMENT dans le cluster
  ports:
  - port: 80
    targetPort: 8080
```

**Use case :** Communication intra-cluster (Ingress → Service)

---

```yaml
# NodePort
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: NodePort         # ← Accessible depuis l'extérieur
  ports:
  - port: 80             # ← Port du Service
    nodePort: 30080      # ← Port du Node (30000-32767)
    targetPort: 8080     # ← Port du Pod
```

**Use case :** Exposition externe sans Ingress (utilisé en dev/test)

---

```yaml
# LoadBalancer
apiVersion: v1
kind: Service
metadata:
  name: public-service
spec:
  type: LoadBalancer     # ← Cloud provider crée un LB externe
  ports:
  - port: 80
    targetPort: 8080
```

**Use case :** Production cloud (AWS ELB, Azure LB, GCP)

---

```yaml
# Headless Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None        # ← CLÉS : Pas de VIP, direct DNS
  selector:
    app: mysql
  ports:
  - port: 3306
```

**Use case :** StatefulSet (DNS stable par pod)

DNS resolves to :
- `mysql-0.mysql-headless.default.svc.cluster.local` → IP du Pod 0
- `mysql-1.mysql-headless.default.svc.cluster.local` → IP du Pod 1

---

### Ingress - Routage Avancé

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    secretName: tls-secret
  rules:
  - host: example.com
    http:
      paths:
      - path: /api/v1(/|$)(.*)      # ← Regex with groups
        pathType: ImplementationSpecific
        backend:
          service:
            name: api-service
            port:
              number: 8000
      - path: /docs
        pathType: Prefix
        backend:
          service:
            name: docs-service
            port:
              number: 80
```

**Routage :**
- `/api/v1/users` → API Service (rewrite to `/users`)
- `/docs/api` → Docs Service (path = `/docs/api`)

---

## 📊 Tableau Comparatif Complet

| Feature | Deployment | StatefulSet | DaemonSet | Ingress |
|---------|-----------|------------|-----------|---------|
| **Pod Names** | Random | Ordered (web-0) | Auto | N/A |
| **Replicas** | Configurable | Configurable | Auto (1 per node) | N/A |
| **Parallel** | Yes | Sequential | Yes | N/A |
| **Headless Service** | Optional | Required | Optional | Required |
| **Persistent Storage** | Possible | Per-pod (templates) | Possible | No |
| **DNS Stable** | No | Yes | No | N/A |
| **Update Strategy** | RollingUpdate | RollingUpdate | RollingUpdate | N/A |
| **Tolerations** | Optional | Optional | Important | N/A |

---

## 🔑 Ressources Critiques pour CKA

### 1. StorageClass → PersistentVolume → PersistentVolumeClaim

```yaml
# 1. StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
reclaimPolicy: Delete
allowVolumeExpansion: true

# 2. PersistentVolume (créé automatiquement)
# (Kubernetes le crée en fonction de la SC)

# 3. PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-pvc
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: "fast-ssd"
  resources:
    requests:
      storage: 100Gi
```

**AccessModes :**
- **ReadWriteOnce (RWO)** : 1 pod, read/write
- **ReadOnlyMany (ROX)** : N pods, read only
- **ReadWriteMany (RWX)** : N pods, read/write

---

### 2. Secrets & ConfigMaps

```yaml
# Secret - Sensitive Data (Base64)
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=        # base64("admin")
  password: cGFzc3dvcmQxMjM= # base64("password123")

---
# ConfigMap - Non-sensitive Data
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  DB_HOST: "mysql.default.svc.cluster.local"
```

**Usage in Deployment :**
```yaml
env:
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: username
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_ENV
```

---

## 🎯 Ordre de Déploiement Typique

```bash
# 1. Namespace
kubectl create namespace production

# 2. Secrets (si nécessaire)
kubectl create secret generic db-secret \
  --from-literal=password=xyz \
  -n production

# 3. ConfigMap (si nécessaire)
kubectl create configmap app-config \
  --from-literal=ENV=prod \
  -n production

# 4. StorageClass (si nécessaire)
kubectl apply -f storage-class.yaml

# 5. PersistentVolumeClaim
kubectl apply -f pvc.yaml

# 6. Service (AVANT Deployment/StatefulSet)
kubectl apply -f service.yaml

# 7. Deployment / StatefulSet
kubectl apply -f deployment.yaml
# OR
kubectl apply -f statefulset.yaml

# 8. Ingress (APRÈS que les Services existent)
kubectl apply -f ingress.yaml
```

---

## 🔄 Networking - Comment Ça Marche

### Pod → Pod (Intra-cluster)

```
Pod A (10.0.0.5)
    ↓ (curl http://svc-b:80)
    ↓
Service svc-b (ClusterIP: 10.1.0.1)
    ↓ (round-robin)
    ├→ Pod B1 (10.0.0.10:8080)
    ├→ Pod B2 (10.0.0.11:8080)
    └→ Pod B3 (10.0.0.12:8080)
```

### External → Pod (via Ingress)

```
Client (1.2.3.4)
    ↓ (GET /api/v1)
    ↓ (Host: example.com)
    ↓
Internet LB (example.com DNS points here)
    ↓
NGINX Ingress Controller Pod
    ↓ (Route to Service)
    ↓
Service api-service (ClusterIP: 10.1.0.2)
    ↓ (Rewrite /api/v1 → /)
    ↓
API Pod (10.0.0.20:5000)
```

---

## 🚀 Déploiement Rapide (Copy-Paste Templates)

### Template 1 : Deployment Simple

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: app:1.0
        ports:
        - containerPort: 8080
        env:
        - name: ENV
          value: production
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
spec:
  selector:
    app: app
  ports:
  - port: 80
    targetPort: 8080
```

### Template 2 : StatefulSet avec Storage

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: "db-headless"
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: db
        image: db:latest
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None
  selector:
    app: db
  ports:
  - port: 3306
```

### Template 3 : Ingress Multi-Service

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    secretName: tls-secret
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8000
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin
            port:
              number: 3000
```

---

## 💡 Commandes Essentielles

```bash
# Voir les ressources
kubectl get all -n <namespace>
kubectl get deploy,statefulset,daemonset -n <namespace>
kubectl get svc,ingress -n <namespace>
kubectl get pv,pvc,sc

# Décrire une ressource
kubectl describe deployment <name>
kubectl describe statefulset <name>
kubectl describe ingress <name>

# Logs
kubectl logs deployment/<name> -n <namespace>
kubectl logs statefulset/<name> -n <namespace>

# Éditer
kubectl edit deployment <name>
kubectl edit service <name>

# Supprimer
kubectl delete deployment <name>
kubectl delete pvc <name>

# Port forward pour tester
kubectl port-forward svc/<service> 8080:80

# Exécuter une commande dans un pod
kubectl exec -it <pod> -- /bin/sh
```

---

## 🎓 Points Clés CKA

✅ **StatefulSet vs Deployment :**
- StatefulSet = BD/Cache = Identité stable
- Deployment = Web/API = Replicas parallèles

✅ **Headless Service :**
- `clusterIP: None` = Direct DNS per pod
- Utilisé avec StatefulSet

✅ **PVC/PV/StorageClass :**
- SC = Template
- PV = Ressource réelle
- PVC = Demande du pod

✅ **Ingress Routing :**
- Hostname-based
- Path-based
- Rewrite-target pour modifications

✅ **DaemonSet + Taints :**
- Tolerations pour s'exécuter sur tous les nœuds
- `operator: Exists` = tolère tout

✅ **InitContainers :**
- Exécutés AVANT les containers
- Utile pour préparer l'état (BD cleanup)

---

Bon entraînement ! 🚀
