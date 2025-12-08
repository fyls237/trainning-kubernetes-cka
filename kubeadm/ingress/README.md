# 🌐 Ingress - Guide Complet CKA

## 🎯 Qu'est-ce qu'un Ingress ?

Un **Ingress** expose des applications HTTP(S) en dehors du cluster Kubernetes. C'est essentiellement un **Load Balancer L7** (couche applicative) qui :

- Route le trafic basé sur le **hostname** (ex: `shop.local`)
- Route basé sur le **path** (ex: `/api/v1`, `/admin`)
- Gère le **TLS/HTTPS**
- Équilibre la charge

### Ingress vs Service

| Aspect | Service | Ingress |
|--------|---------|---------|
| **Niveau** | L4 (Transport) | L7 (Application) |
| **Accès** | Seulement cluster ou NodePort | HTTP/HTTPS externe |
| **Routage** | Port uniquement | Hostname + Path |
| **TLS** | Non | Oui |
| **Exemple** | `svc-front:80` | `shop.local/api/v1` |

---

## 🏗️ Architecture de l'Exemple "Phoenix"

**Cas d'usage :**
- Un seul domaine `shop.local`
- 3 services différents
- Routage par path

```
┌─────────────────────────────────────────┐
│         Client Navigation                │
│      shop.local/api/v1/price            │
└────────────────┬────────────────────────┘
                 │
                 ↓
        ┌────────────────┐
        │    NGINX       │
        │  Ingress       │
        │  Controller    │
        └────────┬───────┘
                 │
     ┌───────────┼───────────┐
     │           │           │
     ↓           ↓           ↓
┌────────┐  ┌────────┐  ┌────────┐
│Frontend│  │Backend │  │ Admin  │
│(Nginx) │  │(Apache)│  │(Nginx) │
│:80     │  │:80→5000│  │:80→8080│
└────────┘  └────────┘  └────────┘
```

---

## 📋 Composants d'un Ingress

### 1️⃣ Namespace

Tout est isolé dans un namespace `prod-app-shop` :

```bash
kubectl create namespace prod-app-shop
```

### 2️⃣ Deployments + Services

**Frontend (Nginx sur port 80) :**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-front
  namespace: prod-app-shop
  labels:
    app: app-shop
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-shop
      tier: frontend
  template:
    metadata:
      labels:
        app: app-shop
        tier: frontend
    spec:
      containers:
      - name: shop-front
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: svc-front
  namespace: prod-app-shop
spec:
  selector:
    app: app-shop
    tier: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

**Backend (Apache sur port 80, exposé en 5000) :**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: prod-app-shop
  labels:
    app: app-shop
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-shop
      tier: backend
  template:
    metadata:
      labels:
        app: app-shop
        tier: backend
    spec:
      containers:
      - name: payment-api
        image: httpd:alpine       # ← Apache
        ports:
        - containerPort: 80       # ← Écoute 80

---
apiVersion: v1
kind: Service
metadata:
  name: svc-pay
  namespace: prod-app-shop
spec:
  selector:
    app: app-shop
    tier: backend
  ports:
  - port: 5000                    # ← Exposé en 5000 au cluster
    targetPort: 80                # ← Apache écoute 80
  type: ClusterIP
```

**Admin (Nginx sur port 80, exposé en 8080) :**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-tools
  namespace: prod-app-shop
  labels:
    app: app-shop
    tier: admin-tools
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-shop
      tier: admin-tools
  template:
    metadata:
      labels:
        app: app-shop
        tier: admin-tools
    spec:
      containers:
      - name: admin-tools
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: svc-admin
  namespace: prod-app-shop
spec:
  selector:
    app: app-shop
    tier: admin-tools
  ports:
  - port: 8080                    # ← Exposé en 8080
    targetPort: 80                # ← Nginx écoute 80
  type: ClusterIP
```

---

### 3️⃣ L'Ingress - Le Routage HTTP(S)

**Fichier exemple : `ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-shop
  namespace: prod-app-shop
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    cert-manager.io/cluster-issuer: selfsigned-issuer
    # 🔒 Sécurité : Rate limiting et headers
    nginx.ingress.kubernetes.io/limit-rpm: "100"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "X-Content-Type-Options: nosniff";
    nginx.ingress.kubernetes.io/load-balance: "round_robin"

spec:
  ingressClassName: nginx          # ← Quel controller ?
  
  # 🔒 TLS/HTTPS
  tls:
  - hosts:
    - shop.local
    secretName: shop-tls           # ← Certificat stocké ici

  # 📍 Routage
  rules: 
  - host: shop.local               # ← Domaine
    http:
      paths:
      # Règle 1 : /api/v1 → Backend (Paiement)
      - path: /api/v1(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: svc-pay
            port:
              number: 5000

      # Règle 2 : /admin → Admin
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: svc-admin
            port:
              number: 8080

      # Règle 3 : / → Frontend (racine)
      - path: /
        pathType: Prefix
        backend:
          service: 
            name: svc-front
            port: 
              number: 80
```

---

## 🔑 Paramètres Clés

### Host (Hostname)

```yaml
- host: shop.local
```

- **Vérification** : Requête HTTP `Host: shop.local`
- **En local** : Ajouter à `/etc/hosts` : `127.0.0.1 shop.local`
- **En cluster** : Utiliser le header : `curl -H "Host: shop.local" http://ingress-ip`

### Path et PathType

**3 Types de pathType :**

| Type | Comportement | Exemple |
|------|------------|---------|
| **Prefix** | Toute requête commençant par ce path | `/admin` matche `/admin`, `/admin/users` |
| **Exact** | Exactement ce path | `/api` matche `/api` uniquement |
| **ImplementationSpecific** | Dépend du controller (regex) | `/api(/\|$)(.*)` pour regex NGINX |

**Règles CKA :**
```yaml
# ✅ Prefix pour les routes simples
- path: /admin
  pathType: Prefix

# ✅ ImplementationSpecific pour regex (rewrite)
- path: /api/v1(/|$)(.*)
  pathType: ImplementationSpecific

# ✅ Exact pour routes précises
- path: /health
  pathType: Exact
```

### Port et TargetPort

**Piège classique CKA :**

```yaml
# Frontend Service
spec:
  ports:
  - port: 80           # ← Port du Service
    targetPort: 80     # ← Port du Container

# Ingress règle
backend:
  service:
    name: svc-front
    port:
      number: 80       # ← Doit matcher port du Service (80)
```

**Backend - Exposé en 5000 :**
```yaml
# Service
spec:
  ports:
  - port: 5000         # ← Port du Service (5000)
    targetPort: 80     # ← Apache écoute 80

# Ingress règle
backend:
  service:
    name: svc-pay
    port:
      number: 5000     # ← Doit matcher port du Service (5000)
```

---

## 🔄 URL Rewrite - Le Challenge Technique

**Le Problème :**

Apache (httpd) sert les fichiers à la racine `/`. Si tu lui envoies `/api/v1/index.html`, il répond 404.

**Requête :**
```
GET /api/v1/index.html
↓ (Ingress reçoit)
↓ (Rewrite target: /$2)
↓ (Apache reçoit)
GET /
↓ (Apache retourne)
It works!
```

**La Magie : L'Annotation**

```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
```

**Explication :**

```yaml
- path: /api/v1(/|$)(.*)  # ← Regex avec 2 groupes
  # Groupe 1 : (/|$)   = "/" ou fin de string
  # Groupe 2 : (.*)    = Reste de l'URL
  
  # Exemple : GET /api/v1/price
  # Groupe 1 : "/"
  # Groupe 2 : "price"
  
  # rewrite-target: /$2  = /$2 = /price
  # Apache reçoit : GET /price
```

**Cas d'usage réels :**

```yaml
# 1. Backend API
- path: /api/v1(/|$)(.*)
  rewrite-target: /$2
  # GET /api/v1/users → GET /users (au backend)

# 2. Admin panel
- path: /admin(/|$)(.*)
  rewrite-target: /$2
  # GET /admin/dashboard → GET /dashboard (au backend)

# 3. Documentation
- path: /docs(/|$)(.*)
  rewrite-target: /docs/$2
  # GET /docs/api → GET /docs/api (garde le prefix)
```

---

## 🔒 TLS/HTTPS et Cert-Manager

### Installer Cert-Manager

```bash
# 1. Ajouter Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. Installer cert-manager
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

# 3. Vérifier
kubectl get pods -n cert-manager
kubectl api-resources | grep cert-manager
```

### Créer un ClusterIssuer (Self-Signed)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}  # ← Self-signed (pas de vrai CA)
```

**En production, utiliser Let's Encrypt :**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Activer TLS dans l'Ingress

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  tls:
  - hosts:
    - shop.local
    secretName: shop-tls    # ← Cert stocké ici
  rules:
  - host: shop.local
    http:
      paths: ...
```

### Vérifier le Certificat

```bash
# 1. Vérifier l'existence du Secret
kubectl get secret shop-tls -n prod-app-shop

# 2. Vérifier la Certificate resource
kubectl get certificate -n prod-app-shop

# 3. Vérifier le statut
kubectl describe certificate shop-tls -n prod-app-shop

# 4. Tester HTTPS
curl -k https://shop.local/   # -k ignore le certificat auto-signé
```

---

## 📚 Annotations Clés NGINX Ingress

### Security

```yaml
annotations:
  # Rate limiting
  nginx.ingress.kubernetes.io/limit-rpm: "100"      # 100 req/min
  nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"

  # Security headers
  nginx.ingress.kubernetes.io/configuration-snippet: |
    more_set_headers "X-Frame-Options: DENY";
    more_set_headers "X-XSS-Protection: 1; mode=block";
    more_set_headers "X-Content-Type-Options: nosniff";

  # Load balancing
  nginx.ingress.kubernetes.io/load-balance: "round_robin"
```

### Rewrite

```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
  nginx.ingress.kubernetes.io/rewrite-target-inplace: "true"  # Garder path
```

### Auth

```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
```

### CORS

```yaml
annotations:
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE"
```

---

## 🔴 Troubleshooting Ingress - CKA

Consultez le **README du dossier ingress/app-shop** pour le troubleshooting complet avec :
- ❌ 404 Not Found
- ❌ 502 Bad Gateway
- ❌ 503 Service Unavailable
- Tableaux de diagnostic
- Exemples CKA

**Commandes rapides :**
```bash
# Vérifier l'Ingress
kubectl get ingress -n prod-app-shop
kubectl describe ingress app-shop -n prod-app-shop

# Vérifier les Services
kubectl get svc -n prod-app-shop
kubectl get endpoints -n prod-app-shop

# Vérifier les Pods
kubectl get pods -n prod-app-shop -o wide

# Tester manuellement
kubectl port-forward -n prod-app-shop svc/svc-front 8080:80
curl http://localhost:8080/

# Logs du controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

---

## 🚀 Cas Pratiques : Patterns CKA

### Pattern 1 : Multi-Service avec Path Rewrite

```yaml
rules:
- host: api.example.com
  http:
    paths:
    - path: /v1(/|$)(.*)
      pathType: ImplementationSpecific
      backend:
        service:
          name: api-v1
          port:
            number: 8080
    - path: /v2(/|$)(.*)
      pathType: ImplementationSpecific
      backend:
        service:
          name: api-v2
          port:
            number: 8080
    - path: /docs
      pathType: Prefix
      backend:
        service:
          name: docs
          port:
            number: 80
```

### Pattern 2 : Multi-Hostname

```yaml
rules:
- host: api.example.com
  http:
    paths:
    - path: /
      backend:
        service:
          name: api-service
- host: web.example.com
  http:
    paths:
    - path: /
      backend:
        service:
          name: web-service
- host: admin.example.com
  http:
    paths:
    - path: /
      backend:
        service:
          name: admin-service
```

### Pattern 3 : Catch-All

```yaml
rules:
- host: "*.example.com"  # ← Wildcard
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: default-service
```

---

## 📋 Checklist Déploiement CKA

```bash
# 1. Créer le namespace
kubectl create namespace prod-app-shop

# 2. Créer les Deployments + Services
kubectl apply -f frontend/
kubectl apply -f backend/
kubectl apply -f admin/

# 3. Vérifier les Services
kubectl get svc -n prod-app-shop
kubectl get endpoints -n prod-app-shop

# 4. Vérifier les Pods
kubectl get pods -n prod-app-shop -o wide

# 5. Créer l'Ingress
kubectl apply -f ingress.yaml

# 6. Vérifier l'Ingress
kubectl get ingress -n prod-app-shop
kubectl describe ingress app-shop -n prod-app-shop

# 7. Tester
curl -H "Host: shop.local" http://ingress-ip/
curl -H "Host: shop.local" http://ingress-ip/api/v1/
curl -H "Host: shop.local" http://ingress-ip/admin/

# 8. Vérifier TLS (si configuré)
kubectl get certificate -n prod-app-shop
curl -k https://shop.local/
```

---

## 📖 Références Officielles

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [NGINX Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [Cert-Manager](https://cert-manager.io/)

---

## 💡 Tips d'Examen CKA

✅ **Ordre de création :**
```bash
1. Namespace
2. Services (doivent exister avant l'Ingress)
3. Deployments
4. Ingress
5. Certificat (optionnel)
```

✅ **Points à retenir :**
- Port Service != Port Container
- Path `/admin` matche `/admin`, `/admin/users`, etc.
- Rewrite-target pour les chemins différents entre Ingress et backend
- Services doivent être `type: ClusterIP` (pas NodePort pour Ingress)

✅ **Erreurs classiques :**
```yaml
# ❌ Oublier le Service
# L'Ingress référence un service qui n'existe pas

# ❌ Mauvais port
# Ingress port: 8080 mais Service port: 80

# ❌ Oublier pathType
# Sans pathType, Ingress peut ne pas créer la règle

# ❌ Service dans un autre namespace
# Ingress et Services doivent être au même endroit
```

✅ **Tester rapidement :**
```bash
# Port-forward pour tester sans Ingress externe
kubectl port-forward -n prod-app-shop svc/svc-front 8080:80

# Test dans un pod de debug
kubectl run -it --rm debug -n prod-app-shop --image=alpine -- sh
wget -O- http://svc-front/
wget -O- http://svc-pay:5000/
wget -O- http://svc-admin:8080/
```
