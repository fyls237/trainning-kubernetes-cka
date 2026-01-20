# 🔐 Gestion des Secrets Kubernetes (GitOps Friendly)

Ce dossier explique comment nous gérons les secrets sensibles (comme les identifiants Docker Registry ou les mots de passe Base de Données) de manière sécurisée en utilisant **Sealed Secrets** de Bitnami.

L'objectif est de pouvoir commiter nos fichiers YAML sur GitHub sans jamais exposer les vrais mots de passe.

---

## 🛠️ Pré-requis : Installation de Sealed Secrets

Avant de pouvoir utiliser des secrets scellés, le contrôleur doit être installé dans le cluster.

1.  **Ajouter le repo Helm** :
    ```bash
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
    helm repo update
    ```

2.  **Installer le Controller** (dans `kube-system`) :
    ```bash
    helm install sealed-secrets-controller sealed-secrets/sealed-secrets \
        --namespace kube-system \
        --set-string fullnameOverride=sealed-secrets-controller
    ```

3.  **Installer le Client (`kubeseal`)** sur votre machine :
    *   Linux : `wget` le binaire depuis les releases GitHub de bitnami-labs/sealed-secrets et mettez-le dans `/usr/local/bin`.

---

## 🔑 Étape 1 : Récupérer la Clé Publique du Cluster

Pour chiffrer un secret hors du cluster (sur votre PC), vous avez besoin de la clé publique de chiffrement utilisée par le contrôleur.

```bash
# Si vous avez accès réseau direct au cluster :
kubeseal --fetch-cert \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=kube-system \
    > pub-cert.pem

# Astuce Troubleshooting (Si erreur réseau/timeout) :
# Utilisez un port-forward pour accéder au contrôleur :
kubectl port-forward service/sealed-secrets-controller -n kube-system 8080:80 &
curl http://localhost:8080/v1/cert.pem > pub-cert.pem
```

Garder ce fichier `pub-cert.pem` précieusement. Il permet de chiffrer, mais pas de déchiffrer.

---

## 📦 Étape 2 : Créer un Secret pour Docker Registry (GHCR)

Nous avons besoin de ce secret pour que Kubernetes puisse télécharger nos images privées depuis GitHub Container Registry.

1.  **Se connecter à Docker localement** :
    ```bash
    # Utilisez votre Token GitHub (PAT) avec droits 'read:packages'
    echo $CR_PAT | docker login ghcr.io -u <GITHUB_USER> --password-stdin
    ```

2.  **Générer le Secret Kubernetes en YAML (Dry Run)** :
    On crée le YAML du secret "clair", mais on ne l'applique pas ! On le passe directement à `kubeseal`.

    ```bash
    kubectl create secret generic ghcr-secret \
        --from-file=.dockerconfigjson=$HOME/.docker/config.json \
        --type=kubernetes.io/dockerconfigjson \
        --namespace prod-database \
        --dry-run=client -o yaml > secret-clair.yaml
    ```

---

## 🔒 Étape 3 : Sceller le Secret (Seal It!)

Utilisez `kubeseal` et votre certificat public pour transformer le secret "clair" en `SealedSecret`.

```bash
kubeseal --cert pub-cert.pem --format yaml < secret-clair.yaml > ghcr-sealed-secret.yaml
```

*   **`secret-clair.yaml`** : ⚠️ DANGER ! Contient vos identifiants. **SUPPRIMEZ-LE IMMÉDIATEMENT**.
*   **`ghcr-sealed-secret.yaml`** : ✅ SÉCURISÉ. Contient des données chiffrées. Vous pouvez le commiter sur git.

---

## 🚀 Étape 4 : Déploiement

Appliquez simplement le secret scellé comme un objet normal.

```bash
kubectl apply -f ghcr-sealed-secret.yaml
```

Le contrôleur SealedSecrets va détecter ce nouvel objet, le déchiffrer avec sa clé privée, et créer automatiquement le Secret natif `ghcr-secret` dans votre namespace.

```bash
# Vérification
kubectl get secrets -n prod-database
```
