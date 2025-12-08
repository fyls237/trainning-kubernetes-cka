# 📦 Applications Stateful - Guide Complet CKA

## 🎯 Applications Stateful vs Stateless

Une **application stateful** maintient l'état entre les requêtes. La perte du pod peut entraîner une **perte de données** ou une **corruption**.

| Aspect | Stateless | Stateful |
|--------|-----------|----------|
| **Données** | Aucune ou éphémères | Persistantes critiques |
| **Controller** | Deployment | StatefulSet |
| **Redémarrage pod** | Transparent | Risqué sans PVC |
| **Déploiement** | Parallèle | Séquentiel |
| **Exemple** | Nginx, API REST | MySQL, PostgreSQL, Redis |

---

## 🏗️ Architectures Pratiques

### Architecture 1 : WordPress + MySQL (Simple)

**Cas d'usage :** Petit site WordPress sur 1 base de données.

```
┌─────────────────────────────────┐
│      WordPress Pod              │
│  - image: wordpress:6.2.1       │
│  - PVC: wp-pvc (10Gi)          │
│  - Var: WORDPRESS_DB_HOST      │
└──────────────┬──────────────────┘
               │ (Connexion MySQL:3306)
┌──────────────▼──────────────────┐
│      MySQL Pod                  │
│  - image: mysql:8.0             │
│  - PVC: mysql-pvc (20Gi)       │
│  - InitContainer: cleanup       │
└─────────────────────────────────┘
```

**Fichiers clés :**
- `wordpress/deployment.yaml` : Déploiement WordPress
- `mysql-wordpress/deployment.yaml` : Déploiement MySQL avec InitContainer
- Services + PVCs associés

### Architecture 2 : Multi-Replica MySQL (Avancé)

**Cas d'usage :** MySQL avec réplication Master-Slave.

```
┌──────────────────┐
│  MySQL Master 0  │  ← Master
│  (Accepte write) │
└────────┬─────────┘
         │ Réplication
    ┌────▼────┬─────────┐
    │          │         │
┌───▼──┐  ┌───▼──┐  ┌──▼───┐
│Slave1│  │Slave2│  │Slave3│
└──────┘  └──────┘  └──────┘
  (Read-only)
```

**À faire :** Utiliser StatefulSet avec configuration d'orchestration (ex: Helm chart MySQL)

---

## 📋 Patterns : WordPress + MySQL

### Pattern 1 : MySQL avec InitContainer Cleanup

**Fichier : `mysql-wordpress/deployment.yaml`**

**Pourquoi un InitContainer ?**

MySQL utilise des fichiers binaires (`.MYI`, `.MYD`, etc.). Si le pod redémarre sans nettoyage :
1. Les anciens fichiers restent dans le PVC
2. MySQL démarre avec un état inconsistant
3. Risque de corruption de données
4. Erreurs comme `Table 'wordpress.wp_posts' doesn't exist`

**Solution :**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-mysql
  namespace: default
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
      # ✅ InitContainer : Exécuté AVANT les containers principaux
      initContainers:
      - name: cleanup-mysql-data
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          set -x
          echo "🧹 Nettoyage du répertoire MySQL..."
          
          # Supprimer TOUS les fichiers (même les liens symboliques)
          if [ -d "/var/lib/mysql" ]; then
            cd /var/lib/mysql
            find . -mindepth 1 -delete  # ← Récursif, tout supprime
            echo "✅ Répertoire vidé"
          fi
          
          # Vérifier
          ls -la /var/lib/mysql/ || echo "Répertoire créé"
          echo "✅ Cleanup terminé"
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: "/var/lib/mysql/"
      
      # Principal container
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

**Étapes d'exécution :**

```
Pod créé
    ↓
InitContainer "cleanup-mysql-data" démarre
    ↓
    → rm -rf /var/lib/mysql/*
    ↓
InitContainer se termine
    ↓
Container "mysql" démarre
    ↓
    → MySQL s'initialise dans un répertoire propre
    ↓
MySQL Ready
```

### Pattern 2 : WordPress avec Déploiement Simple

**Fichier : `wordpress/deployment.yaml`**

```yaml
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
    type: Recreate  # ← RWO = 1 pod à la fois
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
          value: wordpress-mysql  # ← DNS du MySQL pod (Service headless)
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        - name: WORDPRESS_DB_USER
          value: wordpress
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pvc
```

**Points clés :**

| Élément | Importance | Détail |
|---------|-----------|--------|
| **WORDPRESS_DB_HOST** | CRITIQUE | Doit matcher le **Service MySQL** |
| **WORDPRESS_DB_PASSWORD** | CRITIQUE | À stocker dans un Secret |
| **volumeMounts.mountPath** | CRITIQUE | `/var/www/html` = dossier WordPress |
| **type: Recreate** | IMPORTANT | RWO = un seul pod à la fois |

---

## 🔑 Configuration des Secrets

### Créer les Secrets MySQL

```bash
# Root password
kubectl create secret generic mysql-root-pass \
  --from-literal=password=root123

# WordPress user password
kubectl create secret generic mysql-pass \
  --from-literal=password=wordpress123

# Vérifier
kubectl get secrets
kubectl describe secret mysql-pass
```

### Accéder aux Secrets dans les Pods

```yaml
env:
- name: WORDPRESS_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mysql-pass      # ← Secret name
      key: password         # ← Key dans le Secret
```

---

## 🔴 Troubleshooting Stateful Apps

### ❌ WordPress affiche "Erreur lors de la connexion à la base de données"

**Symptôme :**
```
Error establishing a database connection
```

**Causes possibles :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **MySQL n'est pas prêt** | `kubectl get pod wordpress-mysql` → Pending/Crash | Voir logs MySQL : `kubectl logs wordpress-mysql` |
| **Service MySQL inexistant** | `kubectl get svc` → `wordpress-mysql` pas trouvé | Créer le Service MySQL |
| **Mauvais hostname** | `WORDPRESS_DB_HOST: wordpress-mysql` incorrecte | Vérifier exactement le nom du Service |
| **Secret manquant** | `kubectl get secret mysql-pass` → pas trouvé | Créer le Secret avant le Deployment |
| **Mot de passe incorrect** | DB_PASSWORD ne matche pas MYSQL_PASSWORD | Recréer les Secrets |

**Diagnostic complet :**

```bash
# 1. Vérifier que MySQL démarre
kubectl get pods
kubectl describe pod wordpress-mysql

# 2. Vérifier les logs MySQL
kubectl logs wordpress-mysql
# ✅ "ready for connections"
# ❌ "InnoDB: Error: ..."

# 3. Vérifier le Service
kubectl get svc
kubectl get endpoints wordpress-mysql

# 4. Vérifier les Secrets
kubectl get secret
kubectl get secret mysql-pass -o yaml

# 5. Tester la connexion depuis WordPress pod
kubectl exec -it wordpress-xxx -- bash
# mysql -h wordpress-mysql -u wordpress -p
# (entrer le mot de passe)
# SHOW DATABASES;

# 6. Vérifier l'environment de WordPress
kubectl exec -it wordpress-xxx -- sh
# echo $WORDPRESS_DB_HOST
# echo $WORDPRESS_DB_PASSWORD
```

### ❌ MySQL CrashLoopBackOff

**Symptôme :**
```bash
kubectl describe pod wordpress-mysql
# Events: ... CrashLoopBackOff
```

**Causes et solutions :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Répertoire MySQL corrompu** | Logs : "InnoDB: File ... corrupted" | InitContainer cleanup (voir plus haut) |
| **Permissions fichiers** | Logs : "access denied for /var/lib/mysql" | `kubectl exec` et vérifier : `ls -la /var/lib/mysql/` |
| **Espace disque plein** | Logs : "No space left on device" | Nettoyer le PVC ou augmenter la taille |
| **Secret manquant** | Logs : MYSQL_ROOT_PASSWORD vide | Créer les Secrets |

**Debug les logs :**
```bash
kubectl logs wordpress-mysql
# ❌ "InnoDB: File ... is corrupted. ..."
# Solution : Ajouter InitContainer cleanup

# ❌ "failed to initializing innodb ..."
# Solution : Vérifier permissions (chmod 755)

# ❌ "error: Cannot create directory ..."
# Solution : PVC pas montée, vérifier PVC status
```

### ❌ WordPress pod reste en ContainerCreating

**Symptôme :**
```bash
kubectl describe pod wordpress
# Events: ... ContainerCreating (30+ seconds)
```

**Causes :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **WordPress PVC pas Bound** | `kubectl get pvc wp-pvc` → Pending | Vérifier StorageClass, créer SC/PVC |
| **Secret manquant** | Pod attend le Secret | `kubectl apply -f secret.yaml` |
| **Image WordPress introuvable** | Logs : "ImagePullBackOff" | Vérifier le nom de l'image |

**Test du secret :**
```bash
# Créer un pod de test
kubectl run -it --rm test --image=wordpress:6.2.1-apache -- bash

# Essayer de lire les secrets depuis le pod
env | grep WORDPRESS_DB
# Doit afficher les variables d'environnement
```

---

## 🗂️ Ordre de Déploiement CKA

```bash
# Étape 1 : Créer les Secrets
kubectl create secret generic mysql-root-pass --from-literal=password=root123
kubectl create secret generic mysql-pass --from-literal=password=wordpress123

# Étape 2 : Créer la StorageClass (optionnel, peut être déjà existante)
kubectl apply -f storage-class.yaml

# Étape 3 : Créer les PVCs
kubectl apply -f mysql-pvc.yaml
kubectl apply -f wp-pvc.yaml

# Étape 4 : Créer le Service MySQL
kubectl apply -f mysql-service.yaml

# Étape 5 : Créer le Deployment MySQL
kubectl apply -f mysql-wordpress/deployment.yaml

# Étape 6 : Attendre que MySQL soit Ready
kubectl wait --for=condition=ready pod -l app=wordpress,tier=mysql --timeout=300s

# Étape 7 : Créer le Service WordPress (optionnel)
kubectl apply -f wp-service.yaml

# Étape 8 : Créer le Deployment WordPress
kubectl apply -f wordpress/deployment.yaml

# Étape 9 : Vérifier
kubectl get pods
kubectl get pvc
kubectl logs wordpress-xxx
```

---

## 📊 Différence : Deployment vs Déploiement Stateful

### Déploiement Stateless (Nginx)

```yaml
# ✅ Parallèle, sans état
spec:
  strategy:
    type: RollingUpdate
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        # Aucun volume
```

### Déploiement Stateful (WordPress + MySQL)

```yaml
# ⚠️ Séquentiel, avec état
spec:
  strategy:
    type: Recreate      # ← RWO = 1 seul à la fois
  template:
    spec:
      initContainers:
      - name: cleanup    # ← Préparation de l'état
        ...
      containers:
      - name: wordpress
        image: wordpress:6.2.1-apache
        env:
        - name: WORDPRESS_DB_HOST
          value: ...      # ← Dépend d'un autre service
        volumeMounts:
        - name: storage
          mountPath: /var/www/html  # ← Données persistantes
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: wp-pvc
```

---

## 🔐 Secrets et Sécurité

### Créer un Secret depuis Fichier

```bash
# Option 1 : Depuis un fichier
echo "my-secure-password" > ./password.txt
kubectl create secret generic mysql-pass --from-file=password=password.txt
rm password.txt

# Option 2 : Depuis un YAML (Base64 encoded)
kubectl apply -f secret.yaml
```

### Secret YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-pass
type: Opaque
data:
  password: d29yZHByZXNzMTIz  # ← Base64 de "wordpress123"
```

**Créer le Base64 :**
```bash
echo -n "wordpress123" | base64
# d29yZHByZXNzMTIz
```

### Consulter un Secret

```bash
# Voir le Secret (encoded)
kubectl get secret mysql-pass -o yaml

# Décoder
kubectl get secret mysql-pass -o jsonpath='{.data.password}' | base64 -d
# wordpress123
```

---

## 📋 Checklist Déploiement Stateful CKA

```bash
# ✅ Secrets
kubectl create secret generic mysql-root-pass --from-literal=password=...
kubectl create secret generic mysql-pass --from-literal=password=...
kubectl get secret

# ✅ StorageClass
kubectl get storageclass
kubectl describe sc <name>

# ✅ PersistentVolumeClaims
kubectl apply -f *-pvc.yaml
kubectl get pvc

# ✅ Services (surtout pour MySQL)
kubectl apply -f *-service.yaml
kubectl get svc
kubectl get endpoints

# ✅ Deployments
kubectl apply -f mysql-wordpress/deployment.yaml
kubectl apply -f wordpress/deployment.yaml

# ✅ Pods
kubectl get pods -o wide
kubectl logs wordpress-mysql
kubectl describe pod wordpress-mysql

# ✅ Vérifier la PVC
kubectl exec -it wordpress-mysql -- df -h

# ✅ Tester la DB
kubectl exec -it wordpress-mysql -- mysql -u root -p

# ✅ Accéder à WordPress
kubectl port-forward svc/wordpress 8080:80
# Visiter http://localhost:8080
```

---

## 🎯 Patterns CKA à Maîtriser

✅ **Pattern 1 : InitContainer Cleanup (pour BD)**
```yaml
initContainers:
- name: cleanup
  command: ["sh", "-c", "rm -rf /var/lib/mysql/*"]
  volumeMounts:
  - name: data
    mountPath: /var/lib/mysql
```

✅ **Pattern 2 : Environment vars depuis Secrets**
```yaml
env:
- name: WORDPRESS_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mysql-pass
      key: password
```

✅ **Pattern 3 : Service pour la découverte**
```yaml
env:
- name: WORDPRESS_DB_HOST
  value: wordpress-mysql  # ← Service DNS
```

✅ **Pattern 4 : RWO + Recreate Strategy**
```yaml
spec:
  strategy:
    type: Recreate
  # Pour les PVCs RWO (1 seul pod à la fois)
```

---

## 📖 Références Officielles

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

## 💡 Tips d'Examen CKA

✅ **Secrets doivent être créés AVANT les Deployments** qui les referençent.

✅ **InitContainer pour les BDs :**
```bash
# Toujours ajouter pour MySQL/PostgreSQL
# Évite les corruptions
```

✅ **RWO = Recreate Strategy**
```yaml
# Si vous utilisez RWO (block storage)
strategy:
  type: Recreate  # Un seul pod à la fois
```

✅ **DNS Service pour les connecteurs**
```yaml
# Au lieu de l'IP du pod qui peut changer
WORDPRESS_DB_HOST: wordpress-mysql  # Service DNS
```

✅ **Vérifier l'ordre :**
```bash
# 1. Secret créé ? kubectl get secret
# 2. PVC créée ? kubectl get pvc
# 3. Service DNS ? kubectl get svc
# 4. Pod redémarré ? kubectl get pod
```
