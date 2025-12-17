# Le Challenge Expert "Data Vault" 🔒

Maintenant que tu as un moteur capable d'appliquer des règles, voici un scénario complexe qui mélange **Isolation**, **Accès Cross-Namespace** et **Filtrage de Port**.

**Scénario :**
Tu héberges une base de données critique contenant des données clients sensibles.

  * L'application web (Frontend) doit pouvoir lire les données.
  * L'équipe Ops (Admin) doit pouvoir se connecter pour la maintenance depuis un namespace dédié.
  * Tout le reste doit être bloqué.

## 1\. Mise en place du Lab (Setup)

Lance ces commandes pour créer l'environnement (ne perds pas de temps à écrire les pods à la main) :

```bash
# 1. Namespace PROD avec la DB et l'App
kubectl create ns prod-data
kubectl run postgres --image=postgres:alpine --labels="app=db,type=sql" -n prod-data --env="POSTGRES_PASSWORD=password" --port=5432
kubectl run web-app --image=nginx:alpine --labels="app=web,tier=frontend" -n prod-data

# 2. Namespace OPS (Admin) avec un outil de debug
kubectl create ns ops-team
# On ajoute un label au namespace (CRUCIAL pour les policies)
kubectl label namespace ops-team team=admins
kubectl run admin-tool --image=busybox --labels="role=maintenance" -n ops-team -- sleep 3600

# 3. Namespace HACKER (Intrus)
kubectl create ns hackers
kubectl run bad-guy --image=busybox -n hackers -- sleep 3600
```

## 2\. Tes Objectifs (La Network Policy)

Tu dois créer **UNE SEULE** NetworkPolicy nommée `secure-db-access` dans le namespace `prod-data` qui respecte ces 4 règles strictes :

1.  **Cible :** La politique ne doit s'appliquer **qu'au** pod `postgres`. Laisse le pod `web-app` tranquille.
2.  **Accès App (Interne) :** Le pod `web-app` (label `app=web`) situé dans le **même namespace** (`prod-data`) a le droit d'accéder à la DB sur le port **TCP 5432**.
3.  **Accès Admin (Externe) :** Le pod `admin-tool` (label `role=maintenance`) situé dans le namespace **`ops-team`** a le droit d'accéder à la DB sur le port **TCP 5432**.
      * *Indice Expert :* Tu devras utiliser le label du namespace `team=admins`.
4.  **Refus par défaut :** Tout autre trafic vers la DB (venant de `hackers` ou d'ailleurs) doit être rejeté.

## 3\. Comment valider ton travail ? 🧪

Une fois ta policy appliquée, voici les tests de vérité :

  * **Test A (Doit réussir) :** Web App vers DB
    `kubectl exec -it web-app -n prod-data -- nc -zv <IP-POD-POSTGRES> 5432`
    *(Doit afficher "open")*

  * **Test B (Doit réussir) :** Admin vers DB
    `kubectl exec -it admin-tool -n ops-team -- nc -zv <IP-POD-POSTGRES> 5432`
    *(Doit afficher "open")*

  * **Test C (Doit échouer - Timeout) :** Hacker vers DB
    `kubectl exec -it bad-guy -n hackers -- nc -zv <IP-POD-POSTGRES> 5432`

**À toi de jouer \! Propose-moi ton fichier YAML.**
*Rappel : Fais attention à la syntaxe du `namespaceSelector` combiné ou non au `podSelector`.*