# 📚 Index Complet - Guides CKA Training

**Bienvenue !** Vous avez un ensemble complet de guides pratiques pour préparer la certification **CKA (Certified Kubernetes Administrator)**.

---

## 🎯 Démarrer Rapidement

### 1️⃣ Nouveau sur Kubernetes ?
→ **Lire :** [CKA-CHEAT-SHEET.md](./CKA-CHEAT-SHEET.md) 
- Vue globale des ressources Kubernetes
- Quand utiliser quoi
- Templates copy-paste

### 2️⃣ Guides Spécialisés (Choisir un)
→ Cliquez sur votre domaine d'intérêt :

- **[🐳 DaemonSet](./daemonSet/README.md)** - Agents système, Taints/Tolerations
- **[💾 Storage](./storage/README.md)** - PVC/PV/StorageClass, Troubleshooting
- **[🔐 StatefulSet](./statefulset/README.md)** - Identité stable, BD distribuées
- **[🌐 Ingress](./ingress/README.md)** - Routage HTTP(S), Path rewrite, TLS
- **[📦 Applications Stateful](./statefull-app/README.md)** - WordPress + MySQL, InitContainers

### 3️⃣ Vue d'Ensemble
→ **Lire :** [CKA-TRAINING-GUIDES.md](./CKA-TRAINING-GUIDES.md)
- Parcours d'apprentissage recommandé
- Connexions entre les guides
- Résumés par topic

---

## 📁 Structure des Dossiers

```
kubeadm/
├── 📄 CKA-CHEAT-SHEET.md          ← Comparatif rapide
├── 📄 CKA-TRAINING-GUIDES.md      ← Vue d'ensemble
├── 📄 INDEX.md (ce fichier)       ← Navigation
├── 📄 README.md                   ← Installation cluster
│
├── 📂 daemonSet/
│   ├── 📄 README.md (★ Lire !)
│   └── sample.yaml
│
├── 📂 storage/
│   ├── 📄 README.md (★ Lire !)
│   ├── storageclass-nfs.yaml
│   ├── pvc-nfs.yaml
│   └── ...
│
├── 📂 statefulset/
│   ├── 📄 README.md (★ Lire !)
│   └── nginx/
│       ├── statefulset.yaml
│       ├── service.yaml
│       └── storage-class.yaml
│
├── 📂 ingress/
│   ├── 📄 README.md (★ Lire !)
│   └── app-shop/
│       ├── ingress.yaml
│       ├── frontend/deployment.yaml
│       ├── backend/deployment.yaml
│       └── admin/deployment.yaml
│
├── 📂 statefull-app/
│   ├── 📄 README.md (★ Lire !)
│   ├── wordpress/
│   │   └── deployment.yaml
│   └── mysql-wordpress/
│       └── deployment.yaml
│
├── 📂 terraform/ (Provisioning Azure)
└── 📂 ansible/  (Config des nodes)
```

---

## 🎓 Parcours d'Apprentissage

### Débutant (Semaine 1)
1. Lire **CKA-CHEAT-SHEET.md** (30 min)
2. Comprendre **DaemonSet** (1h)
3. Étudier **Storage** (1.5h)

### Intermédiaire (Semaine 2)
4. Maîtriser **StatefulSet** (1.5h)
5. Approfondir **Ingress** (2h)
6. Pratiquer les patterns

### Avancé (Semaine 3)
7. Combiner tout : **Stateful Applications** (2h)
8. Troubleshooting real-world scenarios
9. Mémoriser les patterns CKA

### Exam (Semaine 4)
10. Relire les "À mémoriser" de chaque guide
11. Pratiquer les commandes
12. Passer l'examen !

---

## 🎯 Ressources par Topic CKA

### Core Concepts
- 📖 README.md - Installation d'un cluster complet

### Workloads (Apps, Deployments)
- 📚 **DaemonSet** - Un pod par nœud
- 📚 **StatefulSet** - Apps avec état
- 📚 **Ingress** - Routage externe

### State & Data
- 📚 **Storage** - PVC/PV/StorageClass
- 📚 **StatefulSet** - Identité stable
- 📚 **Stateful Applications** - Real-world examples

### Networking
- 📚 **Ingress** - HTTP(S) routing, TLS, rewrite

### Multi-Container Pods
- 📚 **Stateful Applications** - InitContainers, sidecar patterns

---

## 🔥 Hot Topics pour l'Examen CKA

### ⭐ Absolument à Savoir

| Topic | Où Lire | Temps |
|-------|---------|-------|
| **Taints & Tolerations** | DaemonSet README | 30 min |
| **PVC/PV/StorageClass** | Storage README | 45 min |
| **StatefulSet vs Deployment** | StatefulSet README + Cheat Sheet | 30 min |
| **Headless Service** | StatefulSet README | 15 min |
| **Path Rewrite (Ingress)** | Ingress README | 20 min |
| **Secrets & ConfigMaps** | Cheat Sheet + Stateful Apps | 20 min |
| **InitContainers** | Stateful Apps README | 15 min |

**Total : ~2h30 pour l'essentiel CKA**

---

## 💡 Fiche Mémoire Rapide

### DaemonSet
```yaml
tolerations:
- operator: "Exists"
```

### StorageClass + PVC
```yaml
# SC
provisioner: nfs.csi.k8s.io
parameters:
  server: 4.233.111.136
  share: /data

# PVC
accessModes: [ "ReadWriteMany" ]
storageClassName: nfs-csi
```

### StatefulSet
```yaml
serviceName: "nginx"  # Obligatoire
volumeClaimTemplates:
- metadata:
    name: www
  spec:
    storageClassName: "storage-class"
```

### Ingress Path Rewrite
```yaml
- path: /api/v1(/|$)(.*)
  pathType: ImplementationSpecific
  rewrite-target: /$2  # Backend reçoit /...
```

### InitContainer (BD Cleanup)
```yaml
initContainers:
- name: cleanup
  command: ["sh", "-c", "rm -rf /data/*"]
  volumeMounts:
  - name: data
    mountPath: /data
```

---

## 🔍 Trouver des Réponses

### 🚨 Erreur : Pod Stuck in Pending
→ **[DaemonSet README - Diagnostic PVC Pending](./daemonSet/README.md#️-pod-stuck-in-pending)**

### 🚨 Erreur : 404 Not Found (Ingress)
→ **[Ingress README - Troubleshooting 404](./ingress/README.md#❌-404-not-found)**

### 🚨 Erreur : MySQL CrashLoopBackOff
→ **[Stateful Apps README - MySQL CrashLoop](./statefull-app/README.md#❌-mysql-crashloopbackoff)**

### 🚨 Erreur : PVC pas créée
→ **[Storage README - PVC Stuck in Pending](./storage/README.md#❌-pvc-stuck-in-pending)**

### 🚨 Erreur : Pods ne démarrent pas dans l'ordre
→ **[StatefulSet README - Pods ne démarrent pas en ordre](./statefulset/README.md#❌-pods-ne-démarrent-pas-en-ordre)**

---

## 📚 Références Officielles

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CKA Exam Details](https://www.cncf.io/certification/cka/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cert-Manager](https://cert-manager.io/)

---

## 🚀 Commandes Essentielles Quick Ref

```bash
# VOIR LES RESSOURCES
kubectl get all -n <ns>
kubectl get <resource-type>
kubectl describe <resource-type> <name>

# CRÉER/METTRE À JOUR
kubectl apply -f file.yaml
kubectl apply -f file.yaml --dry-run=client -o yaml

# SUPPRIMER
kubectl delete <resource-type> <name>

# DÉBOGUER
kubectl logs <pod>
kubectl exec -it <pod> -- /bin/sh
kubectl port-forward svc/<service> <port>:<port>

# VÉRIFIER LES BINDINGS
kubectl get pvc -o wide
kubectl get endpoints

# WATCH (temps réel)
kubectl get <resource> --watch
```

---

## ✅ Pré-Examen Checklist

Avant l'examen CKA, vérifiez que vous maîtrisez :

- [ ] Différence Deployment vs StatefulSet vs DaemonSet
- [ ] Créer une PVC, la lier à un Pod
- [ ] Configurer Taints et Tolerations
- [ ] Créer un Ingress avec path rewrite
- [ ] Déboguer un Pod stuck in Pending
- [ ] Utiliser InitContainers
- [ ] Créer des Secrets et les utiliser dans Deployments
- [ ] Configurer une Headless Service pour StatefulSet
- [ ] Les 3 AccessModes (RWO, ROX, RWX)
- [ ] Port vs TargetPort vs NodePort

---

## 📝 Notes Personnelles

```
Ajouter vos notes ici :
_________________________________
_________________________________
_________________________________
```

---

## 🎯 Prochaines Étapes

1. **Choisir un guide** (commencez par DaemonSet ou Storage)
2. **Lire complètement** (ne pas survoler)
3. **Copier les exemples** depuis votre cluster réel
4. **Pratiquer les commandes** de troubleshooting
5. **Mémoriser les patterns** pour l'examen

---

## 💬 Besoin d'Aide ?

Chaque guide README inclut :
- 📊 **Tableaux de diagnostic** pour chaque erreur
- 🔍 **Commandes de debug** pratiques
- ❌ **Exemples INCORRECT** vs ✅ **Exemples CORRECT**
- 📌 **À mémoriser pour l'examen**

**Conseil :** Utilisez le CTRL+F pour chercher votre erreur dans le guide approprié.

---

## 🎓 Ressources Bonus

### Dans ce Repo
- `terraform/` - Provisioning automatique d'une infrastructure Azure
- `ansible/` - Configuration des nœuds Kubernetes
- Fichiers YAML réels que vous pouvez adapter

### Pratique
- [Kubernetes Labs](https://www.killercoda.com/kubernetes)
- [Practice Exams](https://www.kodekloud.com/)
- [Official CKA Practice](https://www.linuxfoundation.org/cka/)

---

Bon courage pour la CKA ! 🚀

**Version :** 2025.01  
**Dernière mise à jour :** Décembre 2025  
**Basé sur :** Kubernetes 1.28+, exemples réels
