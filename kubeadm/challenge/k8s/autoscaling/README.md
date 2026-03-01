# ⚖️ Autoscaling - HorizontalPodAutoscaler

Ce dossier contient les manifestes Kubernetes pour l'autoscaling horizontal du Backend.
L'objectif est d'ajuster automatiquement le nombre de Pods en fonction de la charge CPU et mémoire.

---

## 🏗️ Architecture

```
HPA (portofolio-backend-hpa)
  ├── scaleTarget   → Deployment/portofolio-backend
  ├── minReplicas   → 2
  ├── maxReplicas   → 5
  ├── CPU target    → 50% d'utilisation moyenne
  └── Memory target → 70% d'utilisation moyenne
```

> **Prérequis** : `metrics-server` doit être installé et fonctionnel dans le cluster.

---

## 📦 Configuration HPA (`backend-hpa.yaml`)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: portofolio-backend-hpa
  namespace: prod-database
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: portofolio-backend
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
```

**Déploiement :**
```bash
kubectl apply -f kubeadm/challenge/k8s/autoscaling/backend-hpa.yaml
```

**Vérification :**
```bash
kubectl get hpa -n prod-database
kubectl describe hpa portfolio-backend-hpa -n prod-database
```

---

## � Test de charge — Valider le HPA

### Principe

Le HPA scale UP quand la métrique dépasse la cible sur la moyenne des pods :
```
desiredReplicas = ceil(currentReplicas × (currentValue / targetValue))
```
Exemple : 2 pods à 292% CPU / 50% cible → `ceil(2 × 5.84)` = **5 pods**

### Lancer le test depuis l'intérieur d'un pod

> **Pourquoi de l'intérieur ?** Une NetworkPolicy `default-deny` dans le namespace bloque tout ingress externe. Exécuter le test dans le pod lui-même contourne cette restriction sur le `localhost`.

```bash
# 1. Copier le script dans un pod backend
kubectl cp loadtest.py prod-database/<POD_NAME>:/tmp/loadtest.py

# 2. Lancer le test (50 threads pendant 3 min)
kubectl exec -n prod-database <POD_NAME> -- python3 /tmp/loadtest.py
```

**Contenu de `loadtest.py` :**
```python
import urllib.request, threading, time

URL = "http://localhost:8000/health"
counter = [0]

def worker():
    while True:
        try:
            urllib.request.urlopen(URL, timeout=2)
            counter[0] += 1
        except Exception:
            pass

threads = [threading.Thread(target=worker, daemon=True) for _ in range(50)]
[t.start() for t in threads]
print("START: 50 threads", flush=True)

for i in range(18):
    time.sleep(10)
    print(f"[{(i+1)*10}s] requetes={counter[0]}", flush=True)
```

### Observer le scale-up en temps réel

```bash
# Terminal 1 — lancer le test sur les 2 pods simultanément
kubectl exec -n prod-database <POD_1> -- python3 /tmp/loadtest.py &
kubectl exec -n prod-database <POD_2> -- python3 /tmp/loadtest.py &

# Terminal 2 — surveiller le HPA
watch -n 5 'kubectl get hpa portfolio-backend-hpa -n prod-database && echo && kubectl get pods -n prod-database -l app=portfolio-backend'
```

### Résultats observés

```
# Pendant le test (CPU ~280m / request 100m = 280%)
NAME                    TARGETS             REPLICAS
portfolio-backend-hpa   292%/50%, 56%/70%   5        ← scale-up de 2 → 5

# Pods créés (Pending si plus de CPU disponible sur le node)
portfolio-backend-xxx   1/1     Running   0   40d
portfolio-backend-yyy   0/1     Pending   0   2m   ← insuffisant CPU requests sur le worker
```

> **Note :** Les nouveaux pods restent `Pending` si le nœud worker n'a plus de CPU *requests* disponibles (≠ CPU utilisé). Le HPA a bien réagi — c'est une limite de resources du cluster.

### Après le test — scale-down

Le HPA attend **5 minutes** (cooldown par défaut) avant de réduire les replicas :
```bash
# Vérifier que les métriques redescendent
kubectl top pods -n prod-database -l app=portfolio-backend

# Le HPA revient à minReplicas=2 automatiquement après le cooldown
kubectl get hpa portfolio-backend-hpa -n prod-database --watch
```

---

## �🛠️ Installation de metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Sur un cluster kubeadm auto-géré, ajouter `--kubelet-insecure-tls` (les certificats kubelet n'ont pas de SANs IP) :
```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

```bash
kubectl top nodes
kubectl top pods
```

---

## 🧠 Troubleshooting : `Metrics API not available` sur Azure

### Symptôme
```
$ kubectl top pods
error: Metrics API not available
```

Le pod metrics-server est `Running`, logs propres, mais l'APIService est en timeout :
```
dial tcp <ClusterIP>:443: i/o timeout → status: "False"
```

### Diagnostic rapide

```bash
# 1. Vérifier l'APIService
kubectl get apiservice v1beta1.metrics.k8s.io

# 2. Vérifier les endpoints
kubectl get endpoints metrics-server -n kube-system

# 3. Tester la connectivité depuis le réseau hôte du master (pod hostNetwork)
#    Si le ping vers un Pod sur le worker échoue mais le ping vers le nœud worker passe → problème de tunnel inter-nœuds

# 4. Vérifier le mode d'encapsulation Calico
kubectl get ippools.crd.projectcalico.org -o yaml | grep -E "ipipMode|vxlanMode"
```

### Cause racine : Calico IPIP bloqué par les NSG Azure

| Mode     | Protocole          | Compatible Azure |
|----------|--------------------|-----------------|
| **IPIP** | IP-in-IP (proto 4) | ❌ Bloqué par NSG |
| **VXLAN**| UDP 4789           | ✅ Fonctionne    |

Le kube-apiserver (hostNetwork sur le master) ne peut pas joindre les Pods sur les autres nœuds → l'APIService metrics est injoignable.

### Fix : Passer Calico en mode VXLAN

```bash
# 1. Basculer l'IPPool de IPIP vers VXLAN
kubectl patch ippool default-ipv4-ippool --type merge \
  -p '{"spec": {"ipipMode": "Never", "vxlanMode": "Always"}}'

# 2. Redémarrer les pods calico-node
kubectl -n kube-system rollout restart daemonset/calico-node
kubectl -n kube-system rollout status daemonset/calico-node

# 3. Vérifier
kubectl get apiservice v1beta1.metrics.k8s.io  # → AVAILABLE: True
kubectl top nodes
```

> **Recommandation** : Utiliser VXLAN dès l'initialisation du cluster sur Azure.
