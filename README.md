# trainning-kubernetes-cka
Trainning exemples and installing cluster kubernetes for the CKA
# 🦅 Projet Phoenix : Le Guide Ultime Cloud Native & Platform Engineering

Ce laboratoire est conçu pour forger une expertise pratique, de l'administration système (CKA) jusqu'au Software Engineering, pour la conception de plateformes Cloud souveraines.

## 🧱 SOCLE 1 : L'Administration K8s (Le standard CKA)

### Phase 1 à 4 : Déploiement E-commerce & Sécurité
* **Action :** Provisionner le cluster via Terraform sur Azure (Bastion, Masters, Workers). Déployer l'application avec StatefulSets (PostgreSQL/Redis), Deployments (API/Front), Ingress Nginx, et HPA.
* **Laboratoire de correction :** Supprimez le contrôleur Ingress. Votre site doit tomber. Reconfigurez-le en moins de 5 minutes de mémoire.
* **Documentation :** [Kubernetes Documentation - StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

### Phase 5 : Opérations & Résilience (Day-2 Ops)
* **Action :** Sauvegarde et restauration ETCD, upgrade de cluster avec `kubeadm`, RBAC strict.
* **Laboratoire de correction :** Corrompez volontairement votre cluster (stoppez le service kubelet sur un master). Réparez-le en utilisant votre sauvegarde ETCD. C'est l'essence même de la CKA.

---

## 🏭 SOCLE 2 : Platform Engineering (L'approche Usine)

### Phase 6 : Gestion Multi-Cluster & Gouvernance (Sveltos)
* **Objectif :** Ne plus gérer un cluster, mais une flotte entière.
* **Action :** Installez Sveltos sur le cluster Master (Hub). Créez un `ClusterProfile` pour déployer Cilium et Prometheus automatiquement sur tout nouveau cluster rejoignant la flotte.
* **Laboratoire de correction :** Simulez un cluster "Worker" avec un label incorrect. Sveltos ne doit rien déployer. Corrigez le label et observez la magie de la réconciliation automatique.
* **Documentation :** [Sveltos - Getting Started](https://projectsveltos.github.io/sveltos/getting_started/install/)

### Phase 7 : Infrastructure as Data (Crossplane)
* **Objectif :** Utiliser K8s pour provisionner des ressources Cloud (AWS/Azure) sans Terraform.
* **Action :** Installez Crossplane. Écrivez un manifeste YAML pour provisionner un "Azure Storage Account" ou un "AWS S3 Bucket" directement depuis `kubectl`.
* **Laboratoire de correction :** Allez dans la console AWS/Azure et supprimez le bucket manuellement. Crossplane doit le recréer automatiquement dans les secondes qui suivent (boucle de réconciliation).
* **Documentation :** [Crossplane - Core Concepts](https://docs.crossplane.io/latest/concepts/crossplane-concepts/)

---

## 💻 SOCLE 3 : Software Engineering (Sous le capot)

### Phase 8 : Interagir avec l'API Kubernetes (Golang)
* **Objectif :** Apprendre à coder l'infrastructure pour ne plus dépendre d'outils tiers.
* **Action :** Écrire un script en langage Go qui utilise la librairie `client-go`. Le script doit se connecter au cluster Phoenix, lister tous les namespaces, et supprimer ceux qui ont plus de 30 jours et portent le label `env: test`.
* **Laboratoire de correction :** Créez des namespaces factices avec différentes dates et labels. Exécutez le script. Vérifiez que seuls les bons namespaces ont été purgés.
* **Documentation :** [Go by Example](https://gobyexample.com/) | [Kubernetes Client-Go Examples](https://github.com/kubernetes/client-go/tree/master/examples)

### Phase 9 : Créer un Custom Kubernetes Controller
* **Objectif :** Créer votre propre "cerveau" d'automatisation.
* **Action :** Utilisez le framework `Kubebuilder` pour créer un CRD (Custom Resource Definition) nommé `AppSovereign`. Quand vous déployez ce CRD, votre contrôleur Go doit générer automatiquement le Deployment, le Service, et la NetworkPolicy Cilium restrictive.
* **Laboratoire de correction :** Modifiez manuellement le Service généré par votre contrôleur. Votre code doit le détecter et annuler votre modification pour imposer l'état déclaré.
* **Documentation :** [Kubebuilder Book](https://book.kubebuilder.io/)

---

## 🧠 SOCLE 4 : L'Infrastructure pour l'IA (Le Futur)

### Phase 10 : Préparer le terrain pour les LLMs et le RAG
* **Objectif :** Comprendre comment l'IA s'intègre sur K8s.
* **Action :** 1. Déployez une base de données vectorielle (Milvus ou Qdrant) sur votre cluster via Helm.
    2. Configurez le `Nvidia Device Plugin` sur K8s (en simulant des nœuds GPU si vous êtes sur le Cloud) pour allouer des ressources de calcul aux pods d'IA.
* **Laboratoire de correction :** Lancez un pod d'inférence factice exigeant 2 GPUs alors que vous n'en avez qu'un. Le pod doit rester en statut "Pending". Analysez les logs de l'ordonnanceur (scheduler).
* **Documentation :** [Kubernetes - Schedule GPUs](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/) | [Qdrant on Kubernetes](https://qdrant.tech/documentation/guides/installation/#kubernetes)
