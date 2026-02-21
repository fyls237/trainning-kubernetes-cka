# 🛡️ Network Policies - Sécurisation du Namespace `prod-database`

Ce dossier contient les manifestes Kubernetes de **Network Policies** appliqués au namespace `prod-database`.
Ces règles implémentent le principe de **Zero Trust** : par défaut, aucun pod ne peut communiquer avec un autre. Chaque flux autorisé est explicitement déclaré.

---

## 🏗️ Architecture Réseau

### Flux autorisés (du plus externe au plus interne) :

```
Internet
  │
  ▼
┌─────────────────────────────────┐
│  Ingress Controller (default)   │
│  (namespace: default)           │
└────────┬──────────┬─────────────┘
         │          │
    Port 80    Port 80
         │          │
         ▼          ▼
   ┌──────────┐ ┌──────────┐
   │ Frontend │ │ Backend  │
   │ (React)  │ │ (FastAPI)│
   └──────────┘ └─────┬────┘
                      │
               Port 5432 / 6379
                      │
              ┌───────┴───────┐
              ▼               ▼
        ┌──────────┐   ┌──────────┐
        │ Postgres │   │  Redis   │
        └──────────┘   └──────────┘
```

> **Point Clé** : Le Frontend (React SPA) sert uniquement des fichiers statiques.
> Le code React s'exécute dans le **navigateur du client**, pas dans le pod.
> Les appels API (`/api/...`) transitent par l'Ingress vers le Backend, jamais directement du pod Frontend vers le pod Backend.

---

## 📁 Fichiers

| Fichier | Cible (podSelector) | Source autorisée (from) | Ports |
|---|---|---|---|
| `default-deny.yaml` | Tous les pods (`{}`) | Rien — bloque tout | — |
| `ingress-to-frontend.yaml` | `app=portfolio-frontend` | Pods `ingress-nginx` du namespace `default` | 80 |
| `ingress-to-backend.yaml` | `app=portfolio-backend` | Pods `ingress-nginx` du namespace `default` | 80 |
| `backend-to-database.yaml` | `tier=database` | `app=portfolio-backend` | 5432, 6379 |

---

## 🔑 Concepts Clés

### 1. Default Deny (Le Mur d'Enceinte)
La première règle à poser. Elle bloque **tout** le trafic Ingress (entrant) dans le namespace.
Sans elle, les autres policies ne servent à rien car Kubernetes autorise tout par défaut.

### 2. Logique OR vs AND dans `from`
C'est le piège le plus courant des Network Policies :

```yaml
# ❌ Logique OR (trop permissif) — Deux éléments séparés dans la liste
from:
  - namespaceSelector:    # ← Tiret = élément 1
      matchLabels: ...
  - podSelector:          # ← Tiret = élément 2
      matchLabels: ...
# Résultat : TOUT pod du namespace default OU tout pod ingress-nginx (de N'IMPORTE quel namespace)
```

```yaml
# ✅ Logique AND (correct) — Un seul élément avec les deux sélecteurs
from:
  - namespaceSelector:    # ← Tiret = un seul élément
      matchLabels: ...
    podSelector:          # ← Pas de tiret = même élément, condition ET
      matchLabels: ...
# Résultat : UNIQUEMENT les pods ingress-nginx du namespace default
```

### 3. React SPA vs Next.js SSR
Pour une app **React (SPA)** : l'Ingress doit exposer le Frontend ET le Backend (les appels API partent du navigateur).
Pour une app **Next.js (SSR)** : l'Ingress n'expose que Next.js. Le Backend reste privé (les appels partent du pod serveur).

---

## 🧪 Procédure de Tests

L'outil de test est un pod éphémère `busybox`. Le label `--labels` détermine **l'identité** du pod aux yeux des Network Policies.

### Tests de BLOCAGE (doivent échouer avec `download timed out`)

```bash
# Test 1 : Un pod inconnu ne peut rien joindre (default-deny)
kubectl run test-deny --rm -it --image=busybox -n prod-database \
  --labels="app=intruder" --restart=Never -- \
  wget --spider -T 3 portfolio-frontend-service:80

# Test 2 : Le Frontend ne peut PAS accéder à Postgres
kubectl run test-frontend-pg --rm -it --image=busybox -n prod-database \
  --labels="app=portfolio-frontend" --restart=Never -- \
  wget --spider -T 3 postgres-service:5432

# Test 3 : Le Frontend ne peut PAS accéder à Redis
kubectl run test-frontend-redis --rm -it --image=busybox -n prod-database \
  --labels="app=portfolio-frontend" --restart=Never -- \
  wget --spider -T 3 redis-service:6379

# Test 4 : Un intrus ne peut PAS accéder au Backend
kubectl run test-intruder-backend --rm -it --image=busybox -n prod-database \
  --labels="app=intruder" --restart=Never -- \
  wget --spider -T 3 portfolio-backend-service:80

# Test 5 : Un autre namespace (hors default) ne peut PAS accéder au Frontend
kubectl run test-other-ns --rm -it --image=busybox -n kube-system \
  --restart=Never -- \
  wget --spider -T 3 portfolio-frontend-service.prod-database.svc.cluster.local:80
```

### Tests d'AUTORISATION (doivent se connecter, pas de timeout)

```bash
# Test 6 : Le Backend peut joindre Postgres (port 5432)
kubectl run test-backend-pg --rm -it --image=busybox -n prod-database \
  --labels="app=portfolio-backend" --restart=Never -- \
  wget --spider -T 3 postgres-service:5432

# Test 7 : Le Backend peut joindre Redis (port 6379)
kubectl run test-backend-redis --rm -it --image=busybox -n prod-database \
  --labels="app=portfolio-backend" --restart=Never -- \
  wget --spider -T 3 redis-service:6379
```

> **Note** : Les tests 6 et 7 retournent `error getting response` (exit code 1) car `wget` ne comprend pas les protocoles Postgres/Redis. L'important est qu'il n'y ait **pas** de `download timed out` : la connexion TCP est bien établie.

### Test E2E via l'Ingress

```bash
# Le Frontend répond
curl -H "Host: portfolio.local" http://<IP_DU_NODE>:30729/

# L'API Backend répond
curl -H "Host: portfolio.local" http://<IP_DU_NODE>:30729/api/
```

---

## 📊 Matrice Récapitulative des Tests

| # | Source → Destination | Port | Attendu | Résultat |
|---|---|---|---|---|
| 1 | Intruder → Frontend | 80 | ❌ Timeout | ✅ Bloqué |
| 2 | Frontend → Postgres | 5432 | ❌ Timeout | ✅ Bloqué |
| 3 | Frontend → Redis | 6379 | ❌ Timeout | ✅ Bloqué |
| 4 | Intruder → Backend | 80 | ❌ Timeout | ✅ Bloqué |
| 5 | Autre NS → Frontend | 80 | ❌ Timeout | ✅ Bloqué |
| 6 | Backend → Postgres | 5432 | ✅ Connexion | ✅ OK |
| 7 | Backend → Redis | 6379 | ✅ Connexion | ✅ OK |
| 8 | Ingress → Frontend | 80 | ✅ Réponse | ✅ OK |
| 9 | Ingress → Backend | 80 | ✅ Réponse | ✅ OK |

---

## 🧠 Leçons Apprises

*   **Toujours commencer par `default-deny`.** Sans cette base, les autres policies sont inutiles car Kubernetes est permissif par défaut.
*   **Attention aux tirets YAML dans `from`.** La différence entre OR et AND tient à un seul tiret (`-`). Relisez toujours deux fois.
*   **Tester avec des labels différents.** Le label du pod de test détermine son identité réseau. C'est la méthode la plus fiable pour valider les policies.
*   **`wget: error getting response` ≠ bloqué.** Pour les protocoles non-HTTP (Postgres, Redis), une erreur de protocole signifie que la connexion TCP a réussi. Seul `download timed out` indique un blocage réseau.
