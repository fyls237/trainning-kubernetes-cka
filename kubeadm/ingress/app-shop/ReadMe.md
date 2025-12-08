# 🚀 Projet "Phoenix" : La Migration Microservices

**Contexte :**
L'entreprise "TechCorp" migre son application monolithique vers des microservices sur Kubernetes. Ils ont besoin d'exposer 3 services distincts sous un seul nom de domaine, mais avec des règles de routage précises.

**Tes contraintes d'Architecte :**
* Tout doit être créé dans un **Namespace isolé** (pas dans `default`).
* Tu dois gérer un problème de "conflit de chemin" (Path Rewrite).
* Tu dois gérer des ports de services non-standards (Trap classique CKA).

---

### 📋 Ticket JIRA #1 : Déploiement des Workloads

**Tâche :** Crée les ressources suivantes dans un Namespace nommé `prod-shop`.

1.  **Frontend (Le Site Web) :**
    * Deployment: `shop-front`, Image: `nginx:alpine`, Replicas: 2.
    * Service: `front-svc`, Port exposé: 80.

2.  **Backend (API de Paiement) :**
    * Deployment: `payment-api`, Image: `httpd:alpine` (Apache).
    * Service: `pay-svc`.
    * **⚠️ Piège CKA :** Le conteneur Apache écoute sur le port **80**, mais l'équipe sécu impose que le Service expose le port **5000** à l'intérieur du cluster.

3.  **Admin (Outil Interne) :**
    * Deployment: `admin-tools`, Image: `nginx:alpine`.
    * Service: `admin-svc`, Port exposé: 8080 (Le conteneur est sur le 80).

---

### 📋 Ticket JIRA #2 : La Règle Ingress Complexe

**Tâche :** Crée un seul Ingress nommé `techcorp-ingress` dans le namespace `prod-shop`.

**Cahier des charges du routage :**
* **Domaine (Host) :** `shop.local`
* **Règle 1 :** Tout trafic vers la racine (`/`) doit aller vers le **Frontend**.
* **Règle 2 :** Tout trafic commençant par `/api/v1` doit aller vers le **Backend (Paiement)**.
    * *Challenge Technique :* L'application Apache (`httpd`) sert ses fichiers à la racine (`/`). Si tu lui envoies une requête `/api/v1/index.html`, elle répondra 404. Tu **dois** réécrire l'URL pour qu'Apache reçoive juste `/`.
* **Règle 3 :** Tout trafic commençant par `/admin` doit aller vers l'**Admin**.

---

### 🧪 Critères de Validation (Ta Check-list Expert)

Pour réussir le challenge, tu dois pouvoir exécuter ces commandes depuis ton Bastion (en utilisant ton IP Node et le port NodePort que tu as configuré, ex: `30729`) et obtenir les bons résultats.

1.  **Test Frontend :**
    `curl -H "Host: shop.local" http://10.0.1.6:30729/`
    ➔ Doit répondre : `Welcome to nginx!`

2.  **Test API (Le test critique) :**
    `curl -H "Host: shop.local" http://10.0.1.6:30729/api/v1/`
    ➔ Doit répondre : `It works!` (C'est la page par défaut de l'image httpd).
    *Si tu as une 404 ici, c'est que ton annotation de Rewrite est fausse.*

3.  **Test Admin :**
    `curl -H "Host: shop.local" http://10.0.1.6:30729/admin/`
    ➔ Doit répondre : `Welcome to nginx!` (Note : ici aussi, il faudra peut-être une réécriture si l'admin attend la racine).

### 📋 Ticket JIRA #3 : Sécurisation HTTPS (Encryption in Transit)

**Priorité :** CRITIQUE 🔴
**Assigné à :** Architecte Cloud (Toi)
**Contexte :**
L'audit de sécurité a levé une alerte majeure : les mots de passe et les données de paiement transitent en clair (HTTP) sur le réseau. Nous devons passer tout le trafic entrant via HTTPS immédiatement.
Puisque nous sommes dans un environnement dynamique, nous utiliserons **cert-manager** pour automatiser la gestion des certificats.

**Objectifs Techniques :**

1.  **Infrastructure PKI :** Installer `cert-manager` dans le cluster (Namespace dédié).
2.  **Configuration de l'Autorité (Issuer) :**
    * *Note Architecture :* Comme nous sommes sur un Lab privé sans vrai nom de domaine public (ex: `google.com`), nous ne pouvons pas utiliser le vrai "Let's Encrypt" (qui nécessite une validation DNS publique).
    * **Consigne :** Créer un `ClusterIssuer` de type **SelfSigned** (Auto-signé) pour simuler Let's Encrypt. Cela valide la compétence technique CKA (la syntaxe est identique).
3.  **Mise à jour Ingress :**
    * Modifier l'Ingress `techcorp-ingress` pour activer le TLS.
    * Le certificat doit être stocké automatiquement dans un Secret nommé `shop-tls-secret`.

**Critères de validation (Definition of Done) :**
* L'accès à `http://shop.local` redirige automatiquement vers `https://shop.local`.
* La commande `curl -k -v https://shop.local...` montre une connexion chiffrée (TLS 1.2+).
* Un `kubectl get certificate` montre que le certificat est `Ready`.

---

## 🔧 Troubleshooting Guide - Erreurs Courantes CKA

### ❌ 404 Not Found

**Symptôme :**
```bash
curl -H "Host: shop.local" http://10.0.1.6:30729/api/v1/
# Réponse : 404 Not Found
```

**Causes possibles et solutions :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Path Rewrite mal configuré** | `kubectl get ingress app-shop -n prod-app-shop -o yaml` \| grep rewrite-target | Vérifier l'annotation `nginx.ingress.kubernetes.io/rewrite-target: /$2` dans le metadata |
| **Service n'existe pas** | `kubectl get svc -n prod-app-shop` | Créer le service manquant avec `kubectl apply -f deployment.yaml` |
| **Port incorrect dans Ingress** | `kubectl get svc svc-pay -n prod-app-shop -o yaml` \| grep port | Adapter le `port: 5000` dans l'Ingress si nécessaire |
| **Regex path incorrecte** | Vérifier le path: `/api/v1(/\|$)(.*)` | S'assurer que pathType est `ImplementationSpecific` (pas `Prefix`) |
| **Pod pas prêt** | `kubectl get pods -n prod-app-shop` | Vérifier le status `Running` avec `kubectl logs pod-name -n prod-app-shop` |

**Diagnostic complet :**
```bash
# 1. Vérifier l'Ingress
kubectl describe ingress app-shop -n prod-app-shop

# 2. Vérifier les pods
kubectl get pods -n prod-app-shop
kubectl logs deployment/payment-api -n prod-app-shop

# 3. Tester directement le service
kubectl port-forward svc/svc-pay 5000:5000 -n prod-app-shop
curl http://localhost:5000/

# 4. Vérifier les logs de l'Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

---

### ❌ 502 Bad Gateway

**Symptôme :**
```bash
curl -H "Host: shop.local" http://10.0.1.6:30729/
# Réponse : 502 Bad Gateway
```

**Causes possibles et solutions :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Service n'est pas accessible** | `kubectl get endpoints svc-front -n prod-app-shop` | Vérifier que les endpoints sont populés (IP + port) |
| **Pod en erreur/crashloop** | `kubectl get pods -n prod-app-shop` \| grep -v Running | `kubectl logs pod-name -n prod-app-shop` pour voir les erreurs |
| **Sélecteur de label incorrect** | `kubectl get pods --show-labels -n prod-app-shop` | Vérifier que les labels des pods correspondent à `selector` du Service |
| **Port du conteneur incorrect** | `kubectl get pod pod-name -n prod-app-shop -o yaml` \| grep containerPort | Adapter le port du Service (exemple: nginx écoute 80, pas 8080) |
| **Connexion refusée** | `kubectl exec -it pod-name -n prod-app-shop -- netstat -tlnp` | Vérifier que le service écoute sur le bon port |

**Diagnostic complet :**
```bash
# 1. Vérifier les endpoints
kubectl get endpoints -n prod-app-shop

# 2. Vérifier les labels
kubectl get pods --show-labels -n prod-app-shop

# 3. Tester la connectivité entre pods
kubectl exec -it $(kubectl get pods -n prod-app-shop -l app=payment-api -o jsonpath='{.items[0].metadata.name}') -n prod-app-shop -- sh
# Dans le pod : wget -O- http://svc-pay:5000/ 

# 4. Vérifier les logs du service
kubectl logs -l app=frontend -n prod-app-shop

# 5. Inspecter le Service en détail
kubectl get svc svc-front -n prod-app-shop -o yaml
```

**Exemple CKA typique :**
```yaml
# ❌ INCORRECT : labels ne correspondent pas
apiVersion: v1
kind: Service
metadata:
  name: svc-front
spec:
  selector:
    app: web        # ← Cherche des pods avec label "app: web"
  ports:
  - port: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-front
spec:
  template:
    metadata:
      labels:
        app: frontend  # ← Mais les pods ont "app: frontend" !
```

✅ **CORRECT :** Les labels doivent correspondre partout.

---

### ❌ 503 Service Unavailable

**Symptôme :**
```bash
curl -H "Host: shop.local" http://10.0.1.6:30729/admin/
# Réponse : 503 Service Unavailable
```

**Causes possibles et solutions :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Tous les pods sont down** | `kubectl get pods -n prod-app-shop` | Redémarrer les pods : `kubectl rollout restart deployment/admin-tools -n prod-app-shop` |
| **Replicas = 0** | `kubectl get deployment admin-tools -n prod-app-shop` | Augmenter les replicas : `kubectl scale deployment admin-tools --replicas=2 -n prod-app-shop` |
| **Service n'a pas de backend prêt** | `kubectl get endpoints svc-admin -n prod-app-shop` | Attendre que les pods soient `Running` et `Ready` |
| **Liveness/Readiness probe échoue** | `kubectl describe pod pod-name -n prod-app-shop` | Vérifier les logs et la probe configuration |
| **Ressources insuffisantes** | `kubectl top nodes` et `kubectl top pods -n prod-app-shop` | Ajouter de la mémoire/CPU ou tuer des pods non-essentiels |

**Diagnostic complet :**
```bash
# 1. Vérifier l'état des déploiements
kubectl get deployment -n prod-app-shop

# 2. Vérifier les événements récents
kubectl get events -n prod-app-shop --sort-by='.lastTimestamp'

# 3. Vérifier les ressources
kubectl top nodes
kubectl top pods -n prod-app-shop

# 4. Vérifier les probes
kubectl get pod admin-tools-xyz -n prod-app-shop -o yaml | grep -A 10 "readiness\|liveness"

# 5. Augmenter les replicas
kubectl scale deployment admin-tools --replicas=3 -n prod-app-shop

# 6. Forcer la recréation des pods
kubectl rollout restart deployment/admin-tools -n prod-app-shop
```

**Exemple CKA typique :**
```yaml
# ❌ INCORRECT : Readiness probe échoue
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-tools
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        readinessProbe:
          httpGet:
            path: /health       # ← nginx n'a pas de /health !
            port: 80
          initialDelaySeconds: 0  # ← Pas d'attente avant la probe

---
# ✅ CORRECT
readinessProbe:
  httpGet:
    path: /               # ← nginx répond à /
    port: 80
  initialDelaySeconds: 5  # ← Attendre 5s avant la première probe
  periodSeconds: 10
```

---

## 🎯 Checklist Rapide de Troubleshooting (CKA)

```bash
# Étape 1 : Vérifier l'Ingress
kubectl get ingress -n prod-app-shop
kubectl describe ingress app-shop -n prod-app-shop

# Étape 2 : Vérifier les Services et Endpoints
kubectl get svc,endpoints -n prod-app-shop

# Étape 3 : Vérifier les Pods
kubectl get pods -n prod-app-shop -o wide
kubectl get pods -n prod-app-shop --show-labels

# Étape 4 : Vérifier les logs
kubectl logs deployment/frontend -n prod-app-shop
kubectl logs deployment/payment-api -n prod-app-shop
kubectl logs deployment/admin-tools -n prod-app-shop

# Étape 5 : Tester manuellement
kubectl port-forward svc/svc-front 8080:80 -n prod-app-shop &
curl http://localhost:8080/

# Étape 6 : Vérifier l'Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | tail -20

# Étape 7 : Vérifier la résolution DNS
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n prod-app-shop -- bash
# Dans le pod : nslookup shop.local
```

---

## 📝 Références CKA Utiles

**Documentation officielle :**
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)

**Commandes essentielles :**
```bash
# Débogage d'Ingress
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>
kubectl edit ingress <name> -n <namespace>

# Débogage de Service/Endpoints
kubectl get svc,ep -n <namespace>
kubectl get endpoints <service-name> -n <namespace>

# Débogage de Pods
kubectl get pods -n <namespace> -o wide
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Test de connectivité
kubectl port-forward svc/<service-name> <port>:<port> -n <namespace>
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
```

