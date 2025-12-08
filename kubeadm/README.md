# Installation d'un Cluster Kubernetes avec kubeadm sur Azure

> 📚 **Documentation pédagogique** pour la préparation à la certification **CKA (Certified Kubernetes Administrator)**

---

## 📋 Table des matières

### 🎓 Guides CKA Complets

**Consultez les guides spécialisés dans chaque dossier :**

- 📚 **[DaemonSet Guide](./daemonSet/README.md)** - Taint/Tolerations, troubleshooting Pending
- 🌐 **[Ingress Guide](./ingress/README.md)** - Multi-service routing, path rewrite, TLS/HTTPS
- 💾 **[Storage & Persistence Guide](./storage/README.md)** - PVC/PV, StorageClass, AccessModes
- 🔐 **[StatefulSet Guide](./statefulset/README.md)** - Identité stable, DNS stable, volumeClaimTemplates
- 📦 **[Stateful Applications Guide](./statefull-app/README.md)** - WordPress + MySQL, InitContainers, Secrets

### Installation du Cluster

1. [Architecture de l'infrastructure](#architecture)
2. [Prérequis](#prérequis)
3. [Phase 1 : Provisioning Infrastructure (Terraform)](#phase-1-provisioning)
4. [Phase 2 : Configuration des nœuds](#phase-2-configuration)
5. [Phase 3 : Initialisation du cluster Kubernetes](#phase-3-initialisation)
6. [Phase 4 : Configuration réseau (CNI)](#phase-4-cni)
7. [Phase 5 : Ajout des workers](#phase-5-workers)
8. [Phase 6 : Accès distant avec kubectl](#phase-6-kubectl)
9. [Vérification et tests](#vérification)
10. [Troubleshooting](#troubleshooting)
11. [Commandes utiles pour la CKA](#commandes-cka)

---

## 🏗️ Architecture de l'infrastructure {#architecture}

### Schéma de l'infrastructure provisionnée

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ SSH (port 22)
                           │ Depuis votre IP uniquement
                           ▼
                  ┌────────────────────┐
                  │   Bastion Host     │
                  │  Standard_B1s      │
                  │  1 vCPU, 1 GB RAM  │
                  │  IP: 51.x.x.x      │ ◄── Seule IP publique
                  └──────────┬─────────┘
                             │
                             │ SSH forwarding
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
        │    Azure VNet: 10.0.0.0/16             │
        │    Subnet: 10.0.1.0/24                 │
        │                                         │
        │  ┌──────────────────────────────────┐  │
        │  │  Master Node (Control Plane)     │  │
        │  │  k8s-master-1                    │  │
        │  │  Standard_B2s                    │  │
        │  │  2 vCPU, 4 GB RAM, 30 GB disk   │  │
        │  │  IP privée: 10.0.1.7             │  │
        │  │                                   │  │
        │  │  Composants:                     │  │
        │  │  ├─ kube-apiserver (6443)        │  │
        │  │  ├─ etcd (2379-2380)             │  │
        │  │  ├─ kube-scheduler (10251)       │  │
        │  │  ├─ kube-controller-manager      │  │
        │  │  └─ kubelet (10250)              │  │
        │  └──────────────────────────────────┘  │
        │                                         │
        │  ┌──────────────────────────────────┐  │
        │  │  Worker Node                     │  │
        │  │  k8s-worker-1                    │  │
        │  │  Standard_B1ms                   │  │
        │  │  1 vCPU, 2 GB RAM, 30 GB disk   │  │
        │  │  IP privée: 10.0.1.4             │  │
        │  │                                   │  │
        │  │  Composants:                     │  │
        │  │  ├─ kubelet (10250)              │  │
        │  │  ├─ kube-proxy                   │  │
        │  │  └─ containerd (runtime)         │  │
        │  └──────────────────────────────────┘  │
        │                                         │
        └─────────────────────────────────────────┘
```

### Network Security Groups (NSG)

#### Bastion NSG
```
Inbound:
  - Port 22 (SSH) depuis votre IP uniquement

Outbound:
  - Port 22 vers le subnet 10.0.1.0/24
```

#### Master NSG
```
Inbound (depuis le subnet uniquement):
  - Port 22 (SSH)
  - Port 6443 (Kubernetes API)
  - Port 2379-2380 (etcd)
  - Port 10250-10252 (kubelet, scheduler, controller)
  - Trafic interne illimité
```

#### Worker NSG
```
Inbound:
  - Port 22 (SSH) depuis le subnet
  - Port 10250 (kubelet)
  - Port 30000-32767 (NodePort services)
  - Trafic interne illimité
```

---

## 🔧 Prérequis {#prérequis}

### Sur votre machine locale

- **Terraform** >= 1.5.0
- **Azure CLI** (authentifié)
- **kubectl** >= 1.28
- **SSH key pair** (`~/.ssh/id_rsa`)

### Vérifications

```bash
# Version Terraform
terraform version

# Authentification Azure
az login
az account show

# Clé SSH
ls -la ~/.ssh/id_rsa.pub
```

---

## 🚀 Phase 1 : Provisioning Infrastructure avec Terraform {#phase-1-provisioning}

### 1.1 Configuration des variables

```bash
cd kubeadm/terraform

# Copier le fichier d'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos valeurs
nano terraform.tfvars
```

**Paramètres critiques à modifier :**

```hcl
# Votre IP publique pour l'accès SSH
admin_source_ip = "203.0.113.45/32"  # curl ifconfig.me

# Région Azure
location = "westeurope"

# Configuration du cluster (adapté pour Azure Student)
master_count = 1
worker_count = 1
master_vm_size  = "Standard_B2s"   # 2 vCPU, 4 GB RAM
worker_vm_size  = "Standard_B1ms"  # 1 vCPU, 2 GB RAM
bastion_vm_size = "Standard_B1s"   # 1 vCPU, 1 GB RAM
```

### 1.2 Déploiement de l'infrastructure

```bash
# Initialiser Terraform (télécharge les providers)
terraform init

# Valider la syntaxe
terraform validate

# Prévisualiser les changements
terraform plan

# Appliquer (créer l'infrastructure)
terraform apply
# Tapez "yes" pour confirmer
```

**Durée estimée :** 5-10 minutes

### 1.3 Récupérer les informations de connexion

```bash
# Afficher toutes les sorties
terraform output

# IP publique du bastion
terraform output bastion_public_ip

# IPs privées des nœuds
terraform output master_private_ips
terraform output worker_private_ips

# Commandes SSH
terraform output ssh_bastion
terraform output ssh_commands_masters
terraform output ssh_commands_workers
```

**Exemple de sortie :**
```
bastion_public_ip = "51.124.45.67"
master_private_ips = {
  "master-1" = "10.0.1.7"
}
worker_private_ips = {
  "worker-1" = "10.0.1.4"
}
```

---

## ⚙️ Phase 2 : Configuration automatique des nœuds {#phase-2-configuration}

Les nœuds sont **automatiquement configurés** par `cloud-init` au premier boot :

### 2.1 Configuration réalisée automatiquement

✅ **Système**
- Désactivation du swap (`swapoff -a`)
- Synchronisation NTP avec chrony
- Modules kernel (overlay, br_netfilter)
- Paramètres sysctl pour Kubernetes

✅ **Container Runtime**
- Installation de containerd
- Configuration avec systemd cgroup driver

✅ **Kubernetes**
- Installation de kubeadm, kubelet, kubectl v1.28
- Configuration du kubelet
- Activation du service kubelet

✅ **Sécurité**
- Activation de l'accès root via SSH
- Copie de la clé SSH publique

### 2.2 Vérifier la configuration (optionnel)

```bash
# Se connecter au bastion
ssh azureuser@<BASTION_PUBLIC_IP>

# Depuis le bastion, se connecter au master
ssh azureuser@10.0.1.7

# Vérifier que le swap est désactivé
sudo swapon --show
# Doit être vide

# Vérifier containerd
sudo systemctl status containerd

# Vérifier kubelet (non démarré, normal avant kubeadm init)
sudo systemctl status kubelet

# Vérifier les versions installées
kubeadm version
kubelet --version
kubectl version --client

# Vérifier la synchronisation NTP
timedatectl
chronyc tracking
```

---

## 🎯 Phase 3 : Initialisation du cluster Kubernetes {#phase-3-initialisation}

### 3.1 Se connecter au master node

```bash
# Depuis votre PC, avec agent forwarding
ssh-add ~/.ssh/id_rsa  # Ajouter la clé à l'agent
ssh -A azureuser@<BASTION_PUBLIC_IP>

# Depuis le bastion
ssh azureuser@10.0.1.7

# Passer en root (obligatoire pour kubeadm)
sudo su -
```

### 3.2 Initialiser le cluster

```bash
# Récupérer l'IP privée du master
MASTER_IP=$(hostname -I | awk '{print $1}')
echo "Master IP: $MASTER_IP"

# Initialiser le cluster avec kubeadm
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$MASTER_IP \
  --control-plane-endpoint=$MASTER_IP:6443 \
  --upload-certs
```

**Options expliquées :**
- `--pod-network-cidr` : Range d'IPs pour les pods (utilisé par Flannel)
- `--apiserver-advertise-address` : IP sur laquelle l'API server écoute
- `--control-plane-endpoint` : Endpoint pour les autres masters (HA)
- `--upload-certs` : Partage les certificats pour les autres masters

**⏱️ Durée :** 2-3 minutes

### 3.3 Résultat attendu

```
[init] Using Kubernetes version: v1.28.x
[preflight] Running pre-flight checks
[certs] Generating certificates
[kubeconfig] Writing "admin.conf" file
[kubelet-start] Starting the kubelet
[control-plane] Creating static Pod manifests
[etcd] Creating static Pod manifest for local etcd
[wait-control-plane] Waiting for the kubelet to boot up the control plane
[apiclient] All control plane components are healthy
[upload-config] Storing the configuration used in ConfigMap
[mark-control-plane] Marking the node as control-plane
[bootstrap-token] Generating bootstrap token

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following:

kubeadm join 10.0.1.7:6443 --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

**💾 IMPORTANT : Sauvegarder la commande `kubeadm join` !**

### 3.4 Configurer kubectl pour root

```bash
# Toujours en tant que root sur le master
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Tester kubectl
kubectl get nodes
```

**Résultat attendu :**
```
NAME           STATUS     ROLES           AGE   VERSION
k8s-master-1   NotReady   control-plane   1m    v1.28.x
```

⚠️ **Status `NotReady`** est normal : le plugin réseau (CNI) n'est pas encore installé.

---

## 🌐 Phase 4 : Installation du plugin réseau (CNI) {#phase-4-cni}

### 4.1 Pourquoi un CNI ?

Le CNI (Container Network Interface) permet :
- Communication entre pods sur différents nœuds
- Attribution d'IPs aux pods
- Implémentation des NetworkPolicies

### 4.2 Installer Flannel

```bash
# Toujours en tant que root sur le master
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

**Flannel utilise :**
- **VXLAN** : Encapsulation réseau
- **Pod CIDR** : 10.244.0.0/16 (doit correspondre à `--pod-network-cidr`)

### 4.3 Vérifier l'installation

```bash
# Attendre que les pods Flannel soient Ready (30-60 secondes)
kubectl get pods -n kube-system -w

# Vérifier que le nœud est maintenant Ready
kubectl get nodes
```

**Résultat attendu :**
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master-1   Ready    control-plane   3m    v1.28.x
```

### 4.4 Vérifier les composants système

```bash
# Tous les pods système doivent être Running
kubectl get pods -n kube-system

# Composants attendus:
# - coredns (2 replicas)
# - etcd-k8s-master-1
# - kube-apiserver-k8s-master-1
# - kube-controller-manager-k8s-master-1
# - kube-scheduler-k8s-master-1
# - kube-flannel-ds-xxx
# - kube-proxy-xxx
```

---

## 👷 Phase 5 : Ajout des worker nodes {#phase-5-workers}

### 5.1 Se connecter au worker

```bash
# Depuis le bastion
ssh azureuser@10.0.1.4  # IP du worker

# Passer en root
sudo su -
```

### 5.2 Joindre le cluster

```bash
# Utiliser la commande fournie par kubeadm init
kubeadm join 10.0.1.7:6443 --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

**⏱️ Durée :** 1-2 minutes

### 5.3 Vérifier sur le master

```bash
# Retourner sur le master
# Vérifier que le worker est ajouté
kubectl get nodes
```

**Résultat attendu :**
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master-1   Ready    control-plane   10m   v1.28.x
k8s-worker-1   Ready    <none>          2m    v1.28.x
```

### 5.4 Labelliser le worker (optionnel)

```bash
# Ajouter un label pour identifier les workers
kubectl label node k8s-worker-1 node-role.kubernetes.io/worker=worker

# Vérifier
kubectl get nodes
```

**Résultat :**
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master-1   Ready    control-plane   10m   v1.28.x
k8s-worker-1   Ready    worker          2m    v1.28.x
```

---

## 💻 Phase 6 : Accès distant avec kubectl {#phase-6-kubectl}

### 6.1 Récupérer le kubeconfig

**Option A : SSH avec cat (recommandé)**

```bash
<<<<<<< HEAD
# Depuis votre PC
ssh -J azureuser@<BASTION_IP> azureuser@10.0.1.7 \
=======
Cette commande utilise SSH avec ProxyJump pour récupérer le fichier `/etc/kubernetes/admin.conf` du master via le bastion et le place dans `~/.kube/config` sur votre machine locale.
# Depuis votre PC
ssh -J azureuser@<BASTION_PUBLIC_IP> azureuser@<MASTER_PRIVATE_IP> \
>>>>>>> feat/azurefile
  'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/config

# Modifier les permissions
chmod 600 ~/.kube/config
```

**Option B : SCP via bastion**

```bash
# Sur le master, copier pour azureuser
sudo cp /etc/kubernetes/admin.conf /home/azureuser/admin.conf
sudo chown azureuser:azureuser /home/azureuser/admin.conf

# Depuis votre PC
<<<<<<< HEAD
scp -o ProxyJump=azureuser@<BASTION_IP> \
  azureuser@10.0.1.7:/home/azureuser/admin.conf \
=======
scp -o ProxyJump=azureuser@<BASTION_PUBLIC_IP> \
  azureuser@<MASTER_PRIVATE_IP>:/home/azureuser/admin.conf \
>>>>>>> feat/azurefile
  ~/.kube/config
```

### 6.2 Créer un tunnel SSH

```bash
<<<<<<< HEAD
# Créer un tunnel pour rediriger le port 6443
ssh -L 6443:10.0.1.7:6443 -N azureuser@<BASTION_IP>
=======
Cette commande ouvre un tunnel SSH du port local 6443 vers le port 6443 du master (via le bastion), permettant de rediriger l'API server sur localhost.
# Créer un tunnel pour rediriger le port 6443
ssh -L 6443:<MASTER_PRIVATE_IP>:6443 -N azureuser@<BASTION_PUBLIC_IP>
>>>>>>> feat/azurefile

# Laisser ce terminal ouvert
```

### 6.3 Modifier le kubeconfig pour utiliser localhost

```bash
# Dans un autre terminal
<<<<<<< HEAD
# Modifier l'adresse du serveur API
sed -i 's|https://10.0.1.7:6443|https://127.0.0.1:6443|g' ~/.kube/config
=======
Cette commande remplace l'adresse de l'API server dans le kubeconfig par `127.0.0.1` pour utiliser le tunnel SSH local.
# Modifier l'adresse du serveur API
sed -i 's|https://<MASTER_PRIVATE_IP>:6443|https://127.0.0.1:6443|g' ~/.kube/config
>>>>>>> feat/azurefile
```

### 6.4 Désactiver la vérification TLS (dev/test uniquement)

```bash
# Le certificat n'inclut pas 127.0.0.1 par défaut
kubectl config set-cluster kubernetes --insecure-skip-tls-verify=true
```

### 6.5 Tester kubectl

```bash
# Depuis votre PC (avec le tunnel actif)
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

---

## ✅ Vérification et tests {#vérification}

### Test 1 : Déployer un pod de test

```bash
# Créer un pod nginx
kubectl run nginx-test --image=nginx --port=80

# Vérifier le déploiement
kubectl get pods -o wide

# Tester la connectivité
kubectl exec -it nginx-test -- curl localhost
```

### Test 2 : Créer un Deployment avec Service

```bash
# Créer un deployment
kubectl create deployment web --image=nginx --replicas=3

# Exposer avec un service NodePort
kubectl expose deployment web --type=NodePort --port=80

# Récupérer le NodePort
kubectl get svc web
# Exemple: 80:30123/TCP

# Tester (depuis le bastion ou un nœud)
curl http://10.0.1.4:30123
```

### Test 3 : Vérifier la résolution DNS

```bash
# Créer un pod de test
kubectl run busybox --image=busybox:1.28 --rm -it --restart=Never -- sh

# Dans le pod
nslookup kubernetes.default
nslookup web.default.svc.cluster.local
```

### Test 4 : NetworkPolicy

```bash
# Créer un pod backend
kubectl run backend --image=nginx --labels=app=backend

# Créer un pod frontend
kubectl run frontend --image=busybox --labels=app=frontend -- sleep 3600

# Tester la connectivité (doit fonctionner)
kubectl exec frontend -- wget -qO- http://$(kubectl get pod backend -o jsonpath='{.status.podIP}')

# Créer une NetworkPolicy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
EOF

# Tester (doit toujours fonctionner)
kubectl exec frontend -- wget -qO- http://$(kubectl get pod backend -o jsonpath='{.status.podIP}')
```

---

## 🔧 Troubleshooting {#troubleshooting}

### Problème : Node en status NotReady

**Diagnostic :**
```bash
kubectl describe node <node-name>
kubectl get pods -n kube-system | grep -v Running
```

**Solutions :**
```bash
# Sur le nœud concerné
sudo systemctl restart kubelet
sudo journalctl -u kubelet -f

# Vérifier containerd
sudo systemctl status containerd
sudo crictl ps
```

### Problème : Pod en ImagePullBackOff

**Diagnostic :**
```bash
kubectl describe pod <pod-name>
```

**Solutions :**
```bash
# Vérifier le nom de l'image
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'

# Tester la connectivité internet depuis le pod
kubectl run test --image=busybox --rm -it -- wget -O- google.com
```

### Problème : Pod en CrashLoopBackOff

**Diagnostic :**
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Logs de l'instance précédente
kubectl describe pod <pod-name>
```

### Problème : DNS ne fonctionne pas

**Diagnostic :**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Solutions :**
```bash
# Redémarrer CoreDNS
kubectl rollout restart deployment/coredns -n kube-system

# Vérifier la configuration
kubectl get configmap coredns -n kube-system -o yaml
```

### Problème : Permission denied SSH

**Solution :**
```bash
# Utiliser agent forwarding
ssh-add ~/.ssh/id_rsa
ssh -A azureuser@<BASTION_IP>
```

### Problème : Token expiré pour join

**Solution :**
```bash
# Sur le master, créer un nouveau token
kubeadm token create --print-join-command
```

---

## 📝 Commandes utiles pour la CKA {#commandes-cka}

### Gestion des nœuds

```bash
# Lister les nœuds
kubectl get nodes
kubectl get nodes -o wide

# Détails d'un nœud
kubectl describe node <node-name>

# Drainer un nœud (maintenance)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Marquer un nœud comme non-schedulable
kubectl cordon <node-name>

# Réactiver un nœud
kubectl uncordon <node-name>

# Supprimer un nœud du cluster
kubectl delete node <node-name>
```

### Gestion des pods

```bash
# Lister les pods
kubectl get pods
kubectl get pods -A  # Tous les namespaces
kubectl get pods -o wide  # Avec IPs et nœuds

# Créer un pod
kubectl run nginx --image=nginx

# Créer un pod avec commande
kubectl run busybox --image=busybox --rm -it --restart=Never -- sh

# Logs d'un pod
kubectl logs <pod-name>
kubectl logs <pod-name> -f  # Follow
kubectl logs <pod-name> --previous  # Instance précédente

# Exécuter une commande dans un pod
kubectl exec -it <pod-name> -- /bin/bash

# Copier des fichiers
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file

# Supprimer un pod
kubectl delete pod <pod-name>
kubectl delete pod <pod-name> --force --grace-period=0
```

### Gestion des deployments

```bash
# Créer un deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Scaler un deployment
kubectl scale deployment nginx --replicas=5

# Mettre à jour l'image
kubectl set image deployment/nginx nginx=nginx:1.21

# Rollback
kubectl rollout undo deployment/nginx
kubectl rollout history deployment/nginx

# Exposer un deployment
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Gestion des services

```bash
# Lister les services
kubectl get svc
kubectl get svc -o wide

# Créer un service
kubectl expose pod nginx --port=80 --name=nginx-svc

# Types de services
kubectl expose deployment nginx --type=ClusterIP --port=80
kubectl expose deployment nginx --type=NodePort --port=80
kubectl expose deployment nginx --type=LoadBalancer --port=80
```

### ConfigMaps et Secrets

```bash
# Créer un ConfigMap
kubectl create configmap app-config --from-literal=key1=value1
kubectl create configmap app-config --from-file=config.properties

# Créer un Secret
kubectl create secret generic db-secret --from-literal=password=secret123
kubectl create secret tls tls-secret --cert=cert.crt --key=cert.key

# Utiliser dans un pod
kubectl run app --image=nginx --env="KEY=value"
```

### Namespace

```bash
# Lister les namespaces
kubectl get namespaces

# Créer un namespace
kubectl create namespace dev

# Utiliser un namespace
kubectl get pods -n dev
kubectl config set-context --current --namespace=dev

# Supprimer un namespace
kubectl delete namespace dev
```

### Labels et Selectors

```bash
# Ajouter un label
kubectl label pod nginx env=prod

# Lister avec labels
kubectl get pods --show-labels
kubectl get pods -l env=prod

# Sélectionner par label
kubectl get pods -l 'env in (prod,dev)'
kubectl get pods -l env!=test
```

### RBAC

```bash
# Créer un ServiceAccount
kubectl create serviceaccount my-sa

# Créer un Role
kubectl create role pod-reader --verb=get,list,watch --resource=pods

# Créer un RoleBinding
kubectl create rolebinding read-pods --role=pod-reader --serviceaccount=default:my-sa

# Vérifier les permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
```

### Debugging

```bash
# Events du cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Utilisation des ressources (nécessite metrics-server)
kubectl top nodes
kubectl top pods

# Informations du cluster
kubectl cluster-info
kubectl cluster-info dump

# API resources
kubectl api-resources
kubectl explain pod.spec.containers
```

### Fichiers YAML

```bash
# Générer un YAML sans créer
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

# Appliquer un fichier
kubectl apply -f pod.yaml

# Appliquer un répertoire
kubectl apply -f ./manifests/

# Supprimer depuis un fichier
kubectl delete -f pod.yaml
```

### Backup et Restore (etcd)

```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Vérifier le backup
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db

# Restore etcd
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore
```

---

## 📚 Ressources pour la CKA

### Documentation officielle
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)

### Conseils pour l'examen CKA
1. **Maîtriser kubectl** : Pratiquer les commandes impératives
2. **Comprendre l'architecture** : Composants master/worker
3. **Troubleshooting** : Savoir lire les logs et events
4. **YAML** : Générer avec `--dry-run=client -o yaml`
5. **Temps** : L'examen dure 2h, gérer son temps
6. **Documentation** : Autorisée pendant l'examen
7. **Pratiquer** : Installer/détruire des clusters régulièrement

---

## 🧹 Nettoyage

Pour détruire l'infrastructure :

```bash
cd kubeadm/terraform
terraform destroy
```

---

## 📊 Résumé des ports Kubernetes

| Composant | Port(s) | Protocole | Description |
|-----------|---------|-----------|-------------|
| kube-apiserver | 6443 | TCP | Kubernetes API |
| etcd | 2379-2380 | TCP | Client/Peer communication |
| kube-scheduler | 10259 | TCP | Scheduler (secure) |
| kube-controller-manager | 10257 | TCP | Controller manager (secure) |
| kubelet | 10250 | TCP | Kubelet API |
| kube-proxy | 10256 | TCP | Kube-proxy healthz |
| NodePort | 30000-32767 | TCP/UDP | Services externes |
| Flannel VXLAN | 8472 | UDP | Overlay network |

---

**✅ Cluster Kubernetes opérationnel !** 🎉

**Date de création :** 2025-10-09  
**Infrastructure :** Azure (Bastion Host)  
**Orchestration :** Terraform  
**Installation :** kubeadm  
**CNI :** Flannel  
**Version K8s :** 1.28.x
