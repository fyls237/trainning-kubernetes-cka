# 📚 DaemonSet - Guide Complet CKA

## 🎯 Qu'est-ce qu'un DaemonSet ?

Un **DaemonSet** est une ressource Kubernetes qui garantit qu'une copie d'un Pod s'exécute sur **chaque nœud** du cluster. C'est idéal pour :

- **Monitoring** : Prometheus node-exporter, Datadog agent
- **Logging** : Filebeat, Fluentd, Logstash
- **Networking** : Calico, Weave, kube-proxy
- **Storage** : Ceph, GlusterFS
- **Node Management** : Node janitor, GPU plugin

### Différences clés avec les Deployments

| Aspect | DaemonSet | Deployment |
|--------|-----------|-----------|
| **Nombre de replicas** | 1 par nœud (automatique) | Défini manuellement |
| **Placement** | Tous les nœuds (sauf taints) | N'importe quel nœud |
| **Mise à jour** | RollingUpdate ou OnDelete | RollingUpdate ou Recreate |
| **Cas d'usage** | Agent système, monitoring | Applications stateless |

---

## 📋 Anatomie d'un DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  updateStrategy:
    type: RollingUpdate  # OnDelete pour pas de mise à jour auto
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      # ⭐ IMPORTANT : Tolérances pour les taints
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      
      # ⭐ Sélecteur de nœud optionnel
      nodeSelector:
        kubernetes.io/os: linux
      
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

---

## 🔧 Commandes Essentielles CKA

```bash
# Créer un DaemonSet
kubectl apply -f daemonset.yaml

# Lister les DaemonSets
kubectl get daemonsets -n monitoring
kubectl get ds -n monitoring        # Alias

# Voir les détails
kubectl describe daemonset node-exporter -n monitoring

# Voir les pods créés par le DaemonSet
kubectl get pods -l app=node-exporter -n monitoring

# Éditer un DaemonSet
kubectl edit daemonset node-exporter -n monitoring

# Vérifier le nombre de pods attendus vs réels
kubectl get daemonset node-exporter -n monitoring -o wide

# Supprimer un DaemonSet
kubectl delete daemonset node-exporter -n monitoring

# Vérifier les stratégies de mise à jour
kubectl get daemonset node-exporter -n monitoring -o yaml | grep -A 5 updateStrategy
```

---

## 🚀 Stratégies de Mise à Jour

### 1. RollingUpdate (Défaut)
```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Nombre max de pods non dispo pendant MàJ
```
**Utilisation :** Pour les mises à jour progressives sans interruption complète.

### 2. OnDelete
```yaml
spec:
  updateStrategy:
    type: OnDelete
```
**Utilisation :** Quand tu veux contrôler manuellement quand les pods sont remplacés.

---

## 🔴 Troubleshooting - Les Erreurs Courantes CKA

### ❌ Pod ne s'exécute pas sur un nœud (Taint)

**Symptôme :**
```bash
kubectl get pods -o wide
# Pod en "Pending" sur certains nœuds
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Taint node-role.kubernetes.io/master** | `kubectl describe node master-node` → voir "Taints" | Ajouter `tolerations` pour master/control-plane dans le DaemonSet |
| **Taint custom (GPU, SSD)** | `kubectl describe node` → voir "Taints: gpu=true:NoSchedule" | Ajouter `tolerations` spécifique au taint |
| **Taint NoExecute** | Le pod est évincé du nœud | Ajouter `tolerationSeconds: 300` pour tolérer temporairement |
| **Pas de tolération correspondante** | Pod reste Pending indéfiniment | Matcher exactement `key`, `operator`, `value`, `effect` |

**Diagnostic complet :**
```bash
# 1. Voir tous les taints des nœuds
kubectl describe nodes | grep -A 5 "Taints"

# 2. Voir les tolérances du DaemonSet
kubectl get daemonset <name> -o yaml | grep -A 20 "tolerations"

# 3. Vérifier l'état des pods
kubectl get pods -o wide
kubectl describe pod <pod-name>
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : Pod reste Pending sur master
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-agent
spec:
  template:
    spec:
      containers:
      - name: agent
        image: monitoring:1.0
      # ← Pas de tolérances ! Le pod ne peut pas s'exécuter sur master

---
# ✅ CORRECT : Pod s'exécute partout
spec:
  tolerations:
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
```

---

### ❌ Pod Stuck in Pending

**Symptôme :**
```bash
kubectl describe pod <pod-name>
# Events: ... 0/3 nodes are available: 3 Insufficient memory
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Ressources insuffisantes** | `kubectl describe node` → see "Allocated resources" | Réduire les `requests` ou ajouter des nœuds |
| **NodeSelector non satisfait** | Pod a `nodeSelector: gpu: "true"` mais pas de nœud matchant | Ajouter les labels aux nœuds : `kubectl label node <node> gpu=true` |
| **Affinity constraint impossible** | Pod demande affinity avec pod X qui n'existe pas | Ajuster l'affinity ou créer les pods requis d'abord |
| **No nodes available** | `kubectl get nodes` → Aucun nœud prêt | Attendre que les nœuds soient `Ready` |
| **Taint incompatible** | Voir section précédente | Ajouter tolérances |

**Diagnostic complet :**
```bash
# 1. Voir la raison du Pending
kubectl describe pod <pod-name> | grep -A 10 "Events"

# 2. Vérifier les ressources des nœuds
kubectl describe nodes
kubectl top nodes

# 3. Vérifier les labels des nœuds
kubectl get nodes --show-labels

# 4. Vérifier les requests du pod
kubectl get pod <pod-name> -o yaml | grep -A 10 "resources"

# 5. Voir les événements du cluster
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : NodeSelector ne matche aucun nœud
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gpu-monitor
spec:
  template:
    spec:
      nodeSelector:
        accelerator: nvidia    # ← Aucun nœud a ce label !
      containers:
      - name: gpu-monitor
        image: gpu-monitor:1.0
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"

---
# ✅ CORRECT
# 1. Labelliser les nœuds
$ kubectl label node worker-1 accelerator=nvidia
$ kubectl label node worker-2 accelerator=nvidia

# 2. Ou utiliser tolerations et laisser s'exécuter partout
spec:
  template:
    spec:
      containers:
      - name: gpu-monitor
        image: gpu-monitor:1.0
        resources:
          requests:
            memory: "512Mi"    # ← Ressources réalistes
            cpu: "100m"
```

---

### ❌ Pod CrashLoopBackOff

**Symptôme :**
```bash
kubectl get pods
# Pod en "CrashLoopBackOff" ou "Crash"
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Image inexistante** | `kubectl logs <pod>` → ImagePullBackOff | Corriger le nom de l'image |
| **Cmd/Args invalides** | Logs vides ou erreur de commande | Vérifier `command` et `args` |
| **Fichier config manquant** | Pod attend un ConfigMap/Secret | Créer les ConfigMaps/Secrets requis |
| **Permission refusée** | Pod tente accès à /var/run/docker.sock | Vérifier les permissions ou utiliser `privileged: true` |
| **Probe échoue** | Pod démarre mais liveness probe échoue | Ajuster la probe ou ajouter `initialDelaySeconds` |

**Diagnostic complet :**
```bash
# 1. Voir les logs du pod
kubectl logs <pod-name> --all-containers=true

# 2. Voir les événements
kubectl describe pod <pod-name> | grep -A 20 "Events"

# 3. Voir les tentatives de redémarrage
kubectl get pod <pod-name> -o yaml | grep -A 5 "restartCount"

# 4. Entrer dans le pod pour déboguer (si possible)
kubectl exec -it <pod-name> -- /bin/sh
```

**Exemple CKA :**
```yaml
# ❌ INCORRECT : Pod crash
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  template:
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:latest
        volumeMounts:
        - name: logs
          mountPath: /var/log    # ← Essaie d'accéder à /var/log
      volumes:
      - name: logs
        hostPath:
          path: /var/log         # ← Path n'existe pas !
          type: Directory

---
# ✅ CORRECT
volumes:
- name: logs
  hostPath:
    path: /var/log
    type: DirectoryOrCreate    # ← Crée le répertoire s'il n'existe pas
```

---

### ❌ DaemonSet ne crée pas assez de Pods

**Symptôme :**
```bash
kubectl get daemonset <name>
# Desired: 5, Current: 3, Ready: 3
# (Pas tous les nœuds ont le pod)
```

**Table de Diagnostic :**

| Cause | Diagnostic | Solution |
|-------|-----------|----------|
| **Certains nœuds pas Ready** | `kubectl get nodes` → Voir le status | Attendre que les nœuds se connectent |
| **Taints incompatibles** | Voir section "Pod Stuck in Pending" | Ajouter tolérances |
| **NodeSelector trop restrictif** | DaemonSet a `nodeSelector` que certains nœuds ne matchent pas | Relâcher le nodeSelector ou labelliser les nœuds |
| **Affinity impossible** | Pod ne peut pas se placer sur certains nœuds | Vérifier l'affinity config |
| **Throttling de création** | Le controller crée les pods lentement | C'est normal, attendre quelques secondes |

**Diagnostic complet :**
```bash
# 1. Comparer Desired vs Current vs Ready
kubectl get daemonset <name> -o wide

# 2. Voir les pods par nœud
kubectl get pods -o wide | grep <daemonset-label>

# 3. Identifier les nœuds manquants
kubectl get nodes
# Comparer avec les pods créés

# 4. Vérifier l'état des nœuds
kubectl describe node <node-name> | grep -A 5 "Taints\|Labels"
```

**Exemple CKA :**
```bash
# Scénario : DaemonSet "node-monitor" mais seuls 2 pods sur 4 nœuds
$ kubectl get daemonset node-monitor
# Desired: 4, Current: 2, Ready: 2

# 1. Vérifier les nœuds
$ kubectl get nodes
# NAME          STATUS   ROLES
# master        Ready    control-plane,master
# worker-1      Ready    <none>
# worker-2      Ready    <none>
# worker-3      Ready    <none>

# 2. Vérifier les taints
$ kubectl describe node master | grep Taints
# Taints: node-role.kubernetes.io/master:NoSchedule

$ kubectl describe node worker-3 | grep Taints
# Taints: spot-instance=true:NoSchedule

# 3. Solution : Ajouter tolérances au DaemonSet
tolerations:
- key: node-role.kubernetes.io/master
  operator: Exists
  effect: NoSchedule
- key: spot-instance
  operator: Equal
  value: "true"
  effect: NoSchedule
```

---

### ❌ Pod ImagePullBackOff

**Symptôme :**
```bash
kubectl describe pod <pod-name>
# Failed to pull image "monitoring/agent:1.0": rpc error: code = Unknown
```

**Solutions :**
```bash
# 1. Vérifier que l'image existe
docker pull prom/node-exporter:latest

# 2. Vérifier les imagePullSecrets
kubectl get secrets

# 3. Ajouter le secret au DaemonSet
spec:
  template:
    spec:
      imagePullSecrets:
      - name: docker-secret
      containers:
      - name: agent
        image: private-registry.com/agent:1.0

# 4. Forcer le re-pull
kubectl rollout restart daemonset <name> -n <namespace>
```

---

## 🎯 Checklist Rapide de Troubleshooting DaemonSet

```bash
# Étape 1 : Vérifier l'état global
kubectl get daemonset <name> -o wide
kubectl get pods -l app=<selector>

# Étape 2 : Vérifier les nœuds
kubectl get nodes
kubectl describe node <node-name>

# Étape 3 : Vérifier les logs
kubectl logs daemonset/<name> --all-containers=true
kubectl logs <pod-name>

# Étape 4 : Vérifier la configuration
kubectl get daemonset <name> -o yaml
kubectl describe daemonset <name>

# Étape 5 : Vérifier les événements
kubectl get events --sort-by='.lastTimestamp' | grep <name>

# Étape 6 : Forcer la mise à jour
kubectl rollout restart daemonset/<name>

# Étape 7 : Déboguer dans un pod
kubectl exec -it <pod-name> -- /bin/sh
```

---

## 📊 Tableau Complet des Erreurs CKA

| État | Cause Probable | Commandes de Debug | Solution |
|------|---------------|-------------------|----------|
| **Pending** | Taint/NodeSelector/Ressources | `describe node`, `describe pod` | Tolérances, labels, resources |
| **CrashLoopBackOff** | Image/Cmd/Config | `logs`, `describe pod` | Corriger image/args/config |
| **ImagePullBackOff** | Image non trouvée/Auth | `describe pod` → "Failed to pull" | Corriger image, imagePullSecrets |
| **FailedScheduling** | No node available | `describe pod` → "Events" | Ajouter nœuds, tolérances |
| **Running (mais pas Ready)** | Liveness/Readiness probe fail | `logs`, `describe pod` | Ajuster probes |
| **Desired != Current** | Taints/NodeSelector restrictif | `get daemonset -o wide` | Vérifier tolérances/labels |

---

## 🔐 Cas Spéciaux : DaemonSets Privilégiés

Certains DaemonSets ont besoin d'accès privilegié (ex: CNI plugins, monitoring système).

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cni-plugin
spec:
  template:
    spec:
      hostNetwork: true          # ← Accès réseau du host
      hostPID: true              # ← Accès PID du host
      hostIPC: true              # ← Accès IPC du host
      containers:
      - name: plugin
        image: cni-plugin:1.0
        securityContext:
          privileged: true        # ← Mode privilégié
        volumeMounts:
        - name: host-root
          mountPath: /host
      volumes:
      - name: host-root
        hostPath:
          path: /
          type: Directory
      tolerations:
      - operator: "Exists"        # ← Tolère TOUS les taints
        effect: "NoSchedule"
      - operator: "Exists"
        effect: "NoExecute"
```

⚠️ **À utiliser avec précaution en production !**

---

## 📝 Références CKA

- [DaemonSet Official Docs](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity)

---

## 💡 Tips CKA

✅ **Toujours tester :**
```bash
# Avant de déployer
kubectl apply -f daemonset.yaml --dry-run=client -o yaml

# Après le déploiement
kubectl get daemonset <name> -o wide
kubectl get pods -o wide | grep <selector>
kubectl logs daemonset/<name> -f  # Suivi en temps réel
```

✅ **Pour les exams :**
- Mémoriser la structure YAML de base
- Connaître les taints/tolerations par cœur
- Savoir diagnostiquer avec `describe` et `logs`
- Tester immédiatement après chaque modification

✅ **Patterns courants CKA :**
```yaml
# Pattern 1 : DaemonSet sur tous les nœuds (y compris master)
tolerations:
- operator: "Exists"

# Pattern 2 : DaemonSet sur workers only (pas master)
nodeSelector:
  node-role.kubernetes.io/worker: ""

# Pattern 3 : DaemonSet spécifique GPU
nodeSelector:
  accelerator: nvidia
tolerations:
- key: nvidia-gpu
  operator: Equal
  value: "true"
  effect: NoSchedule
```
