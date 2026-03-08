# ⏰ CronJob - Sauvegarde PostgreSQL Automatisée

Ce dossier contient le manifeste du CronJob de backup nocturne de la base de données PostgreSQL.
C'est un excellent cas pratique pour comprendre les **Jobs/CronJobs Kubernetes** et leur interaction avec le reste du cluster (réseau, stockage, secrets).

---

## 🏗️ Architecture

Un **CronJob** n'est pas un simple Pod qui tourne en boucle. C'est une hiérarchie de ressources :

```
CronJob (postresql-backup)
  └── Job  ← créé automatiquement à chaque déclenchement selon le schedule
       └── Pod (postgresql-backup)
            ├── pg_dump → /backup/backup_YYYYMMDD_HHMMSS.sql
            └── Volume (PVC: database-pvc, NFS, 3Gi)
```

| Composant | Rôle |
|---|---|
| **CronJob** | Définit le planning et les règles de concurrence |
| **Job** | Garantit que le Pod est lancé jusqu'à terminaison réussie |
| **Pod** | Exécute `pg_dump` dans l'image `postgres:18.1-alpine` |
| **PVC `database-pvc`** | Stockage NFS persistant pour les fichiers `.sql` |
| **Secret `postgres-secret`** | Fournit le mot de passe via la variable `PGPASSWORD` |

---

## 🔑 Notions essentielles sur les CronJobs (CKA)

### 1. Syntaxe Cron

```
┌──────── minute (0-59)
│ ┌────── heure (0-23)
│ │ ┌─── jour du mois (1-31)
│ │ │ ┌─ mois (1-12)
│ │ │ │ ┌ jour de la semaine (0-6, 0=Dimanche)
│ │ │ │ │
* * * * *
```

| Expression | Signification |
|---|---|
| `0 2 * * *` | Tous les jours à 2h du matin |
| `*/5 * * * *` | Toutes les 5 minutes |
| `0 9 * * 1` | Chaque lundi à 9h |
| `0 0 1 * *` | Le 1er de chaque mois à minuit |

### 2. Paramètres Clés

| Paramètre | Valeurs | Comportement |
|---|---|---|
| `concurrencyPolicy` | `Allow` (défaut) | Lance un nouveau Job même si le précédent tourne encore |
| | `Forbid` | Skip le déclenchement si un Job est déjà en cours **(recommandé pour backup)** |
| | `Replace` | Annule le Job en cours et en lance un nouveau |
| `restartPolicy` (Pod) | `OnFailure` | Kubernetes redémarre le Pod en cas d'échec **(pour Jobs)** |
| | `Never` | Crée un nouveau Pod à chaque tentative |
| `backoffLimit` | entier (défaut: 6) | Nombre de tentatives avant de marquer le Job en `Failed` |
| `successfulJobsHistoryLimit` | entier (défaut: 3) | Nombre de Jobs réussis conservés |
| `failedJobsHistoryLimit` | entier (défaut: 1) | Nombre de Jobs échoués conservés |

> **Attention** : `restartPolicy: Always` est **interdit** dans un Job/CronJob. Kubernetes refusera le manifeste.

### 3. Hiérarchie YAML (piège fréquent)

Les paramètres `concurrencyPolicy`, `schedule`, `successfulJobsHistoryLimit` appartiennent au **spec du CronJob**, PAS au `jobTemplate`.

```yaml
# ✅ CORRECT
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid      # ← au niveau CronJob
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure  # ← au niveau Pod

# ❌ INCORRECT (erreur silencieuse possible)
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      concurrencyPolicy: Forbid   # ← ignoré ou rejeté
```

---

## 📦 Configuration du CronJob (`backup-database.yaml`)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postresql-backup
  namespace: prod-database
spec:
  schedule: "0 2 * * *"       # Chaque nuit à 2h UTC
  concurrencyPolicy: Forbid    # Pas de backups simultanés
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: postgresql-backup  # ⚠️ Nécessaire pour la NetworkPolicy
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:18.1-alpine  # Version alignée avec le serveur PostgreSQL
            command:
              - /bin/sh
              - -c
              - "pg_dump -h postgres-service -U postgres -d portfolio_db
                 -f /backup/backup_$(date +%Y%m%d_%H%M%S).sql"
            env:
              - name: PGPASSWORD              # Variable attendue par pg_dump
                valueFrom:
                  secretKeyRef:
                    name: postgres-secret
                    key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: database-pvc
```

---

## 🛠️ Commandes Utiles

### Gestion du CronJob

```bash
# Déployer
kubectl apply -f backup-database.yaml

# État du CronJob
kubectl get cronjob -n prod-database

# Historique des Jobs déclenchés
kubectl get jobs -n prod-database

# Logs du dernier backup
kubectl logs -n prod-database -l app=postgresql-backup

# Lancer un backup manuel immédiatement (sans attendre le schedule)
kubectl create job --from=cronjob/postresql-backup manual-backup-$(date +%s) -n prod-database
```

### Vérification des sauvegardes

```bash
# Lister les fichiers sur le PVC (via un pod temporaire)
kubectl run -it --rm debug --image=alpine --restart=Never -n prod-database \
  --overrides='{"spec":{"volumes":[{"name":"v","persistentVolumeClaim":{"claimName":"database-pvc"}}],"containers":[{"name":"debug","image":"alpine","volumeMounts":[{"name":"v","mountPath":"/backup"}],"command":["sh"]}]}}' \
  -- ls -lh /backup/
```

---

## 🔥 Troubleshooting - Problèmes Rencontrés

### 1. `no kind "PersistentVolume" is registered` ou Pod bloqué en Pending

**Symptôme** : `kind: PersistentVolume` dans le manifeste au lieu de `kind: PersistentVolumeClaim`.

**Cause** : Confusion entre les deux ressources.

| Ressource | Qui la crée ? | Rôle |
|---|---|---|
| `PersistentVolume` (PV) | l'Admin (ou le Provisioner auto) | Le "disque" physique |
| `PersistentVolumeClaim` (PVC) | le Developer | La "demande" de stockage |

Le volume référencé dans un Pod doit toujours pointer vers un **PVC**.

```yaml
# ✅ CORRECT dans le Pod spec
volumes:
- name: backup-storage
  persistentVolumeClaim:
    claimName: database-pvc
```

---

### 2. `concurrencyPolicy` ignoré — Jobs lancés en double

**Symptôme** : Plusieurs Jobs tournent en même temps malgré `concurrencyPolicy: Forbid`.

**Cause** : `concurrencyPolicy` était défini à l'intérieur de `jobTemplate.spec` au lieu du `spec` du CronJob.

**Solution** : Vérifier le niveau YAML avec `kubectl get cronjob postresql-backup -o yaml | grep concurrencyPolicy`.

---

### 3. Pod du backup bloque en `ContainerCreating` ou timeout réseau

**Symptôme** : Le Pod reste bloqué ou `pg_dump` retourne `connection refused / timeout`.

**Cause** : Le namespace `prod-database` a une **NetworkPolicy `default-deny`** qui bloque tout le trafic entrant par défaut.

**Solution** : Le pod doit avoir un label reconnu par la NetworkPolicy autorisant l'accès à PostgreSQL.

```yaml
# 1. Ajouter le label dans le pod template du CronJob
metadata:
  labels:
    app: postgresql-backup   # ← ce label doit exister

# 2. Mettre à jour la NetworkPolicy (backend-to-database.yaml)
spec:
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: portfolio-backend
    - podSelector:
        matchLabels:
          app: postgresql-backup  # ← ajouter cette entrée
```

> **Piège** : Après avoir ajouté le label dans le YAML, il faut **supprimer le Job existant** (pas juste le Pod). Kubernetes ne recrée pas le Pod avec les nouveaux labels tant que le Job parent est vivant.

```bash
kubectl delete job <nom-du-job> -n prod-database
kubectl apply -f backup-database.yaml
# Puis déclencher manuellement
kubectl create job --from=cronjob/postresql-backup test-fix -n prod-database
```

---

### 4. `fe_sendauth: no password supplied`

**Symptôme** : pg_dump échoue avec cette erreur malgré un Secret configuré.

**Cause** : L'env var était nommée `POSTGRES_PASSWORD` (convention de l'image Docker PostgreSQL pour l'initialisation) au lieu de `PGPASSWORD` (variable lue par les outils clients comme `pg_dump`, `psql`).

```yaml
# ❌ Incorrect pour pg_dump
- name: POSTGRES_PASSWORD

# ✅ Correct pour pg_dump / psql
- name: PGPASSWORD
```

---

### 5. `password authentication failed for user "postgres"`

**Symptôme** : pg_dump retourne un échec d'authentification même avec le bon `PGPASSWORD`.

**Cause** : Le PVC contenait des données PostgreSQL créées avec un mot de passe **différent** lors d'un précédent déploiement. Le mot de passe stocké dans le Secret ne correspond pas à ce qui est dans les fichiers de données.

**Solution** : Corriger le mot de passe directement dans PostgreSQL.

```bash
# Connexion au pod postgres (sans mot de passe car on est en local)
kubectl exec -it postgres-0 -n prod-database -- psql -U postgres

# Modifier le mot de passe
ALTER USER postgres PASSWORD 'postgrepass';
\q
```

> **Bonne pratique** : Toujours supprimer le PVC avant de changer le mot de passe dans le Secret, ou s'assurer que le Secret et les données PostgreSQL sont créés ensemble en une seule fois.

---

### 6. `pg_dump: error: server version mismatch`

**Symptôme** :
```
pg_dump: error: server version: 18.1; pg_dump version: 16.x
pg_dump: error: aborting because of server version mismatch
```

**Cause** : La version du **client** pg_dump (dans l'image du CronJob) est plus ancienne que la version du **serveur** PostgreSQL cible. pg_dump refuse de fonctionner dans cette situation.

**Règle** : La version de l'image du CronJob doit être **identique ou plus récente** que le serveur PostgreSQL.

```yaml
# Serveur PostgreSQL = v18.1
# ❌ image: postgres:16        (trop vieux)
# ❌ image: postgres:18        (tag flottant, peut être n'importe quelle sous-version)
# ✅ image: postgres:18.1-alpine  (version exacte, image légère)
```

---

### 7. `pg_dump: error: no such database: postgres`

**Symptôme** : pg_dump se connecte mais ne trouve pas la base.

**Cause** : La commande utilisait `-d postgres` (la base système par défaut) au lieu de `-d portfolio_db`.

```bash
# ❌ Incorrect
pg_dump -h postgres-service -U postgres -d postgres

# ✅ Correct
pg_dump -h postgres-service -U postgres -d portfolio_db
```

---

## 📚 Ressources

*   [Kubernetes Docs — CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
*   [Kubernetes Docs — Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
*   [pg_dump Reference](https://www.postgresql.org/docs/current/app-pgdump.html)
