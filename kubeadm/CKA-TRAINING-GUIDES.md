# 🎓 CKA Training Guides - Vue Globale

Bienvenue dans le **guide complet de formation CKA**. Vous avez créé une infrastructure Kubernetes et plusieurs guides pratiques basés sur **des exemples réels que vous avez utilisés pour vous entraîner**.

---

## 📚 Guides Créés par Sujet CKA

### 1️⃣ **DaemonSet** - Agents Système
📁 **Dossier:** `kubeadm/daemonSet/`
📄 **README:** [daemonSet/README.md](./daemonSet/README.md)

**Qu'allez-vous apprendre ?**
- ✅ Qu'est-ce qu'un DaemonSet vs Deployment
- ✅ Anatomie d'un DaemonSet (serviceName, volumeClaimTemplates)
- ✅ **Taints & Tolerations** (La cause classique CKA : "Pod ne s'exécute pas sur le node")
- ✅ Troubleshooting complet avec tableaux de diagnostic
- ✅ 7 erreurs courantes : Pod Stuck in Pending, CrashLoopBackOff, ImagePullBackOff, etc.
- ✅ Patterns CKA à mémoriser

**Cas réels couverts :**
- Monitoring agents (Prometheus node-exporter)
- Logging agents (Fluentd, Filebeat)
- CNI plugins (Calico, Weave)

**À mémoriser pour l'examen :**
```yaml
tolerations:
- operator: "Exists"  # ← Pour s'exécuter partout (même sur master)
```

---

### 2️⃣ **Storage & Persistence** - Données Durables
📁 **Dossier:** `kubeadm/storage/`
📄 **README:** [storage/README.md](./storage/README.md)

**Qu'allez-vous apprendre ?**
- ✅ Architecture : StorageClass → PersistentVolume → PersistentVolumeClaim
- ✅ 3 AccessModes : RWO, ROX, RWX (qui supporte quoi ?)
- ✅ **Dynamic vs Static Provisioning**
- ✅ Troubleshooting : PVC Stuck in Pending, Mount échoue, Leaking
- ✅ Patterns réels : WordPress + MySQL avec InitContainer

**Basé sur vos fichiers :**
- `storageclass-nfs.yaml` : Classe de stockage NFS avec CSI
- `pvc-nfs.yaml` : PVC simple 5Gi ReadWriteMany
- Déploiements WordPress utilisant des PVCs

**À mémoriser pour l'examen :**
```yaml
# StorageClass
provisioner: nfs.csi.k8s.io
parameters:
  server: 4.233.111.136
  share: /data

# PVC
accessModes:
  - ReadWriteMany
storageClassName: nfs-csi
```

---

### 3️⃣ **StatefulSet** - Applications avec Identité Stable
📁 **Dossier:** `kubeadm/statefulset/`
📄 **README:** [statefulset/README.md](./statefulset/README.md)

**Qu'allez-vous apprendre ?**
- ✅ StatefulSet vs Deployment (la différence CKA classique)
- ✅ Identité stable : `web-0`, `web-1`, `web-2` (prévisible !)
- ✅ **Headless Service** (pourquoi `clusterIP: None` ?)
- ✅ volumeClaimTemplates (une PVC par pod, créée automatiquement)
- ✅ Ordre séquentiel de démarrage et d'arrêt
- ✅ Troubleshooting : Service headless manquant, Pods ne démarrent pas dans l'ordre

**Basé sur vos fichiers :**
- `statefulset.yaml` : 3 replicas Nginx avec persistent storage
- `service.yaml` : Headless Service (clusterIP: None)
- `storage-class.yaml` : Azure file CSI

**À mémoriser pour l'examen :**
```yaml
spec:
  serviceName: "nginx"  # ← OBLIGATOIRE
  
volumeClaimTemplates:
- metadata:
    name: www
  spec:
    storageClassName: "nginx-storage-class"
    resources:
      requests:
        storage: 1Gi
```

**DNS stable :**
```
web-0.nginx.default.svc.cluster.local
web-1.nginx.default.svc.cluster.local
web-2.nginx.default.svc.cluster.local
```

---

### 4️⃣ **Ingress** - Routage HTTP(S) Avancé
📁 **Dossier:** `kubeadm/ingress/`
📄 **README:** [ingress/README.md](./ingress/README.md)

**Qu'allez-vous apprendre ?**
- ✅ Architecture Ingress : Services + Ingress Controller (NGINX)
- ✅ Routage par **hostname** et **path**
- ✅ **Path Rewrite** (Le challenge : Apache reçoit `/` au lieu de `/api/v1/index.html`)
- ✅ **TLS/HTTPS** avec cert-manager (Self-signed pour le lab)
- ✅ Annotations NGINX : rate-limiting, headers de sécurité, load-balancing
- ✅ Troubleshooting : 404, 502, 503 avec diagnostics complets

**Basé sur vos fichiers :**
- `ingress.yaml` : Routage multi-service
  - `/` → Frontend (Nginx)
  - `/api/v1` → Backend (Apache httpd, rewrite-target)
  - `/admin` → Admin (Nginx)
- Déploiements Frontend, Backend, Admin
- Services avec ports non-standards (5000, 8080)

**À mémoriser pour l'examen :**
```yaml
# Path avec Regex et Rewrite
- path: /api/v1(/|$)(.*)
  pathType: ImplementationSpecific  # ← Important
  rewrite-target: /$2               # ← Envoie le groupe 2 au backend

# TLS
tls:
- hosts:
  - shop.local
  secretName: shop-tls
```

**Tableau des erreurs :**
- ❌ **404** : Path/Service manquant, rewrite faux
- ❌ **502** : Service/Pod pas prêt
- ❌ **503** : Tous les replicas down

---

### 5️⃣ **Stateful Applications** - WordPress + MySQL
📁 **Dossier:** `kubeadm/statefull-app/`
📄 **README:** [statefull-app/README.md](./statefull-app/README.md)

**Qu'allez-vous apprendre ?**
- ✅ Architecture : WordPress + MySQL (une seule base)
- ✅ **InitContainers** (exécutés avant les containers principaux)
- ✅ Nettoyage des données MySQL (éviter la corruption)
- ✅ Secrets & Environment variables
- ✅ RWO + Recreate Strategy (1 seul pod à la fois)
- ✅ Service Discovery via DNS

**Basé sur vos fichiers :**
- `wordpress/deployment.yaml` : WordPress avec PVC
- `mysql-wordpress/deployment.yaml` : MySQL avec InitContainer cleanup
- Secrets pour les passwords

**À mémoriser pour l'examen :**
```yaml
# InitContainer pour nettoyage BD
initContainers:
- name: cleanup-mysql-data
  image: busybox:latest
  command: ["sh", "-c", "rm -rf /var/lib/mysql/*"]
  volumeMounts:
  - name: mysql-persistent-storage
    mountPath: "/var/lib/mysql/"

# Strategy RWO
strategy:
  type: Recreate  # ← 1 seul pod à la fois

# Env depuis Secret
env:
- name: WORDPRESS_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mysql-pass
      key: password
```

---

## 🎯 Parcours d'Apprentissage Recommandé

### Semaine 1 : Fondamentaux
1. **Pods & Services** (non couverts ici, mais base)
2. **DaemonSet** - Comprendre les patterns de base
3. **Storage** - Concepts PVC/PV/SC

### Semaine 2 : Avancé
4. **StatefulSet** - Identité stable
5. **Ingress** - Routage HTTP(S)

### Semaine 3 : Mise en Pratique
6. **Stateful Applications** - Combiner tout ensemble
7. **Troubleshooting** - Parcourir les diagnostics de chaque guide

### Examen
- ✅ Relire les "À mémoriser" de chaque section
- ✅ Pratiquer les patterns CKA
- ✅ Mémoriser les commandes essentielles

---

## 🔧 Commandes Essentielles CKA

### Pour chaque ressource type

```bash
# ================== DAEMONSET ==================
kubectl get daemonset -n <namespace>
kubectl describe daemonset <name> -n <namespace>
kubectl logs daemonset/<name> -n <namespace>
kubectl rollout restart daemonset/<name> -n <namespace>

# ================== STORAGE ==================
kubectl get pv,pvc,sc
kubectl describe pvc <name>
kubectl describe pv <name>
kubectl describe sc <name>
kubectl get pvc -o wide  # Voir les bindings

# ================== STATEFULSET ==================
kubectl get statefulset -n <namespace>
kubectl describe statefulset <name> -n <namespace>
kubectl get pods -o wide | grep <statefulset-name>
kubectl scale statefulset <name> --replicas=<n>

# ================== INGRESS ==================
kubectl get ingress -n <namespace>
kubectl describe ingress <name> -n <namespace>
kubectl get endpoints -n <namespace>
kubectl port-forward -n <namespace> svc/<service> <port>:<port>

# ================== DEBUG ==================
kubectl logs <pod> -n <namespace>
kubectl describe pod <pod> -n <namespace>
kubectl exec -it <pod> -n <namespace> -- bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## 📊 Tableau Comparatif : Quand Utiliser Quoi ?

| Besoin | Ressource | Config Clé |
|--------|-----------|-----------|
| **Agent sur tous les nœuds** | DaemonSet | serviceName pas obligatoire, tolerations |
| **Données persistantes partagées** | Storage RWX | StorageClass, PVC |
| **BD avec identité stable** | StatefulSet | serviceName, volumeClaimTemplates |
| **Routage HTTP multi-service** | Ingress | rewrite-target, pathType |
| **WordPress + MySQL** | Deployment + InitContainer | type: Recreate |

---

## 🔗 Connexions entre les Guides

```
┌─────────────────────────────────────────┐
│     STATEFUL APPLICATIONS               │
│  (WordPress + MySQL)                    │
└────────┬──────────────────────┬─────────┘
         │                      │
         ▼                      ▼
   ┌──────────────┐      ┌───────────────┐
   │  STORAGE     │      │  SECRETS      │
   │  (PVC/PV)    │      │  (Passwords)  │
   └──────┬───────┘      └───────────────┘
          │
          ▼
   ┌──────────────┐
   │STATEFULSET   │ ← Pour MySQL (identité stable)
   │ ou           │
   │DEPLOYMENT    │ ← Pour WordPress
   └──────┬───────┘
          │
          ▼
   ┌──────────────────┐
   │   SERVICES       │
   │  (Découverte)    │
   └────────┬─────────┘
            │
            ▼
   ┌──────────────────┐
   │    INGRESS       │ ← Expose WordPress au monde
   │  (Routage HTTP)  │
   └──────────────────┘
```

---

## 💡 Tips pour l'Examen CKA

### ✅ Avant chaque déploiement

```bash
# 1. Lister les ressources
kubectl get all -n <namespace>

# 2. Appliquer le manifeste
kubectl apply -f file.yaml --dry-run=client -o yaml

# 3. Vérifier immédiatement
kubectl get <resource-type> -n <namespace> -w  # Watch mode
kubectl describe <resource-type> <name> -n <namespace>

# 4. Déboguer si problème
kubectl logs <pod> -n <namespace>
kubectl exec -it <pod> -n <namespace> -- /bin/sh
```

### ✅ Erreurs classiques à éviter

- ❌ Oublier le namespace
- ❌ Service et Pod dans des namespaces différents
- ❌ PVC référençant une StorageClass inexistante
- ❌ Oublier `serviceName` dans StatefulSet
- ❌ Oublier `clusterIP: None` pour Headless Service
- ❌ Port Service != Port Container

### ✅ Patterns à mémoriser (Copier-Coller)

Chaque guide contient une section "Patterns CKA" avec du YAML prêt à copier.

---

## 📖 Structure des Dossiers

```
kubeadm/
├── README.md (ce fichier)
├── daemonSet/
│   └── README.md ← Lire pour les Taints/Tolerations
├── ingress/
│   ├── README.md ← Lire pour Path Rewrite et TLS
│   └── app-shop/
│       ├── ingress.yaml (exemple réel)
│       ├── frontend/deployment.yaml
│       ├── backend/deployment.yaml
│       └── admin/deployment.yaml
├── statefulset/
│   ├── README.md ← Lire pour StatefulSet
│   └── nginx/
│       ├── statefulset.yaml (exemple réel)
│       ├── service.yaml (headless)
│       └── storage-class.yaml
├── storage/
│   ├── README.md ← Lire pour PVC/PV/SC
│   ├── pvc-nfs.yaml
│   └── storageclass-nfs.yaml
├── statefull-app/
│   ├── README.md ← Lire pour WordPress + MySQL
│   ├── wordpress/
│   │   └── deployment.yaml
│   └── mysql-wordpress/
│       └── deployment.yaml (avec InitContainer)
├── terraform/
│   └── (Provisioning Azure)
└── ansible/
    └── (Configuration des nœuds)
```

---

## 🎯 Résumé CKA Cheat Sheet

| Ressource | Quand | Service | Ordre |
|-----------|-------|---------|-------|
| **DaemonSet** | Agent/monitoring | Optionnel | N/A |
| **Deployment** | Apps stateless | Oui | Parallèle |
| **StatefulSet** | BD/cache | Headless (clusterIP: None) | Séquentiel |
| **Ingress** | Routing HTTP | Requis | L7 routing |
| **InitContainer** | Préparer l'état | N/A | Avant containers |

---

## 📝 Prochaines Étapes

1. **Lire un guide à la fois** (commencer par DaemonSet ou Storage)
2. **Copier les exemples** de votre déploiement réel
3. **Adapter à votre lab** (changez les noms, IPs, etc.)
4. **Pratiquer les commandes** de troubleshooting
5. **Mémoriser les patterns** pour l'examen

---

## 🆘 Besoin d'Aide ?

Chaque guide inclut :
- 📊 **Tableaux de diagnostic** pour chaque erreur
- 🔍 **Commandes de debug** pratiques
- ❌ **Exemples INCORRECT** vs ✅ **Exemples CORRECT**
- 📌 **À mémoriser pour l'examen**

**Commencez par le guide de troubleshooting du problème que vous rencontrez !**

---

Bon entraînement pour la CKA ! 🚀
