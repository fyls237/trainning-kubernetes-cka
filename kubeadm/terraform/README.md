# Kubernetes Cluster on Azure with Terraform

Ce projet déploie automatiquement un cluster Kubernetes haute disponibilité sur Azure avec **3 nœuds master** et **2 nœuds worker** en utilisant une architecture **Bastion Host** sécurisée (1 seule IP publique).

## 📋 Architecture

```
Internet
   |
   v
[Bastion Host] (1 IP publique)
Standard_B1s: 1 vCPU, 1 GB RAM
   |
   v
[VNet 10.0.0.0/16 - Subnet 10.0.1.0/24]
   |
   ├── k8s-master-1 (IP privée uniquement)
   ├── k8s-master-2 (IP privée uniquement)
   ├── k8s-master-3 (IP privée uniquement)
   ├── k8s-worker-1 (IP privée uniquement)
   └── k8s-worker-2 (IP privée uniquement)
```

### Caractéristiques

| Ressource | Quantité | SKU | Spécifications | IP |
|-----------|----------|-----|----------------|-----|
| Bastion | 1 | Standard_B1s | 1 vCPU, 1 GB, 30 GB | Publique |
| Masters | 3 | Standard_B2s | 2 vCPU, 4 GB, 30 GB | Privée |
| Workers | 2 | Standard_B1ms | 1 vCPU, 2 GB, 30 GB | Privée |

### Réseau
- **VNet**: 10.0.0.0/16
- **Subnet**: 10.0.1.0/24
- **Bastion**: SSH (22) uniquement depuis votre IP
- **Masters**: SSH depuis subnet, 6443 (API), 2379-2380 (etcd), 10250-10252 (kubelet/scheduler/controller)
- **Workers**: SSH depuis subnet, 10250 (kubelet), 30000-32767 (NodePort)

### Configuration automatique (cloud-init)
✅ Synchronisation NTP (chrony)  
✅ Swap désactivé  
✅ Containerd installé et configuré  
✅ kubeadm, kubelet, kubectl v1.28  
✅ Modules kernel (overlay, br_netfilter)  
✅ Root SSH activé avec votre clé  

---

## 🚀 Déploiement

### 1. Prérequis

- **Terraform** >= 1.5.0 ([Installation](https://developer.hashicorp.com/terraform/downloads))
- **Azure CLI** ([Installation](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Clé SSH générée (`ssh-keygen -t rsa -b 4096`)
- Compte Azure actif

### 2. Authentification Azure

```bash
az login
az account list --output table
az account set --subscription "<SUBSCRIPTION_ID>"
```

### 3. Configuration

Copie et modifie le fichier de variables :

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**⚠️ IMPORTANT** : Modifie ces valeurs dans `terraform.tfvars` :

```hcl
# Trouve ton IP publique : curl ifconfig.me
admin_source_ip = "203.0.113.45/32"  # ⚠️ Remplace par TON IP

# Région Azure (optionnel)
location = "westeurope"  # ou eastus, westus2, etc.

# Chemin vers ta clé SSH publique
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

### 4. Déploiement Terraform

```bash
cd kubeadm/terraform

# Initialiser Terraform
terraform init

# Vérifier le plan
terraform plan

# Appliquer (créer l'infrastructure)
terraform apply
```

⏱️ **Durée** : ~5-10 minutes

### 5. Récupérer les IPs

```bash
# Afficher toutes les IPs et commandes SSH
terraform output

# Uniquement les IPs publiques des masters
terraform output master_public_ips

# Uniquement les IPs publiques des workers
terraform output worker_public_ips
```

---

## ⚙️ Configuration Kubernetes

### 1. Initialiser le premier master

Connecte-toi au premier master en tant que root :

```bash
# Récupère l'IP depuis terraform output
ssh azureuser@<MASTER-1-PUBLIC-IP>

# Passe en root
sudo su -

# Récupère l'IP privée du master
MASTER_IP=$(hostname -I | awk '{print $1}')
echo $MASTER_IP

# Initialise Kubernetes
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$MASTER_IP \
  --control-plane-endpoint=$MASTER_IP:6443 \
  --upload-certs
```

**💾 IMPORTANT** : Sauvegarde les commandes de join affichées !

### 2. Configurer kubectl pour root

```bash
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config
```

### 3. Installer le plugin réseau (Flannel)

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### 4. Joindre les autres masters

Sur **master-2** et **master-3**, exécute la commande affichée lors de l'init :

```bash
ssh azureuser@<MASTER-2-PUBLIC-IP>
sudo su -

kubeadm join <MASTER-1-PRIVATE-IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --control-plane --certificate-key <KEY>
```

### 5. Joindre les workers

Sur **worker-1** et **worker-2** :

```bash
ssh azureuser@<WORKER-1-PUBLIC-IP>
sudo su -

kubeadm join <MASTER-1-PRIVATE-IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### 6. Vérifier le cluster

```bash
# Sur master-1
kubectl get nodes
kubectl get pods --all-namespaces
```

Tu devrais voir :
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master-1   Ready    control-plane   5m    v1.28.x
k8s-master-2   Ready    control-plane   3m    v1.28.x
k8s-master-3   Ready    control-plane   2m    v1.28.x
k8s-worker-1   Ready    <none>          1m    v1.28.x
k8s-worker-2   Ready    <none>          1m    v1.28.x
```

---

## 🔗 Accès SSH avec Bastion

### Option 1 : SSH en deux étapes

```bash
# 1. Connecte-toi au bastion
ssh azureuser@<BASTION-PUBLIC-IP>

# 2. Depuis le bastion, accède aux nœuds
ssh <MASTER-1-PRIVATE-IP>
ssh <WORKER-1-PRIVATE-IP>
```

### Option 2 : ProxyJump (direct depuis ton PC)

```bash
# Connexion directe via bastion
ssh -J azureuser@<BASTION-PUBLIC-IP> azureuser@<MASTER-1-PRIVATE-IP>
```

### Option 3 : VS Code Remote-SSH via Bastion

1. Installe l'extension **Remote-SSH** dans VS Code
2. Copie ta clé privée sur le bastion :

```bash
scp ~/.ssh/id_rsa azureuser@<BASTION-PUBLIC-IP>:~/.ssh/
```

3. Ajoute cette configuration dans `~/.ssh/config` :

```bash
# Bastion Host
Host k8s-bastion
  HostName <BASTION-PUBLIC-IP>
  User azureuser
  IdentityFile ~/.ssh/id_rsa

# Masters via Bastion
Host k8s-master-1
  HostName <MASTER-1-PRIVATE-IP>
  User azureuser
  ProxyJump k8s-bastion
  IdentityFile ~/.ssh/id_rsa

Host k8s-master-2
  HostName <MASTER-2-PRIVATE-IP>
  User azureuser
  ProxyJump k8s-bastion
  IdentityFile ~/.ssh/id_rsa

# Workers via Bastion
Host k8s-worker-1
  HostName <WORKER-1-PRIVATE-IP>
  User azureuser
  ProxyJump k8s-bastion
  IdentityFile ~/.ssh/id_rsa
```

4. Dans VS Code : `F1` → `Remote-SSH: Connect to Host` → Choisis `k8s-master-1`

---

## 🧹 Nettoyage

Pour détruire toute l'infrastructure :

```bash
terraform destroy
```

⚠️ Cela supprimera TOUTES les ressources créées.

---

## 📊 Coûts estimés (Azure)

| Ressource | Quantité | SKU | Coût/mois (≈) |
|-----------|----------|-----|---------------|
| Bastion VM | 1 | Standard_B1s | ~€8 |
| Master VMs | 3 | Standard_B2s | ~€60 |
| Worker VMs | 2 | Standard_B1ms | ~€20 |
| IP publique | 1 | Standard | ~€3 |
| Disques | 6 × 30 GB | Standard SSD | ~€12 |
| **TOTAL** | | | **~€103/mois** |

*Prix indicatifs pour West Europe. Architecture bastion = 1 seule IP publique au lieu de 5.*

---

## 🛠️ Dépannage

### Les VMs ne démarrent pas
```bash
# Vérifie les logs cloud-init
ssh azureuser@<VM-IP>
sudo cat /var/log/cloud-init-output.log
```

### Kubeadm init échoue
```bash
# Réinitialise et recommence
kubeadm reset -f
rm -rf /etc/cni/net.d
rm -rf /root/.kube
```

### Les nœuds restent NotReady
```bash
# Vérifie les pods système
kubectl get pods -n kube-system

# Vérifie containerd
systemctl status containerd

# Réinstalle Flannel
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### Problèmes de synchronisation horaire
```bash
# Vérifie chrony
systemctl status chrony
chronyc tracking
```

---

## 📚 Ressources

- [Documentation Kubernetes](https://kubernetes.io/docs/)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Flannel CNI](https://github.com/flannel-io/flannel)

---

## 📝 Notes

- Toutes les VMs utilisent **Ubuntu 22.04 LTS**
- Le cluster utilise **Kubernetes v1.28**
- **Containerd** est le runtime de conteneurs
- **Flannel** avec le réseau pod CIDR `10.244.0.0/16`
- Les VMs redémarrent automatiquement après la configuration initiale

---

**✅ Bon déploiement !**
