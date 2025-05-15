# Configuration des Credentials Jenkins

## Vue d'ensemble

Ce document décrit la configuration des credentials nécessaires pour le bon fonctionnement de Jenkins et du pipeline CI/CD.

## Liste des Credentials

### 1. Credentials Système

- `jenkins-ssh` : Clé SSH pour le nœud master Jenkins
  - Type : SSH avec clé privée
  - Variable : `JENKINS_SSH_PRIVATE_KEY`

- `gitlab-token` : Token API GitLab pour l'intégration Jenkins
  - Type : GitLab API Token
  - Variable : `GITLAB_API_TOKEN`

- `docker-hub` : Credentials Docker Hub standard
  - Type : Username/Password
  - Variables : `DOCKER_USERNAME`, `DOCKER_PASSWORD`

### 2. Credentials Spécifiques AirQuality

- `credentialGitlab` : Token GitLab pour checkout HTTPS
  - Type : Username/Password
  - Username : "oauth2"
  - Password : `GITLAB_API_TOKEN`

- `dockerhub_airquality` : Credentials Docker Hub pour AirQuality
  - Type : Username/Password
  - Variables : `DOCKER_USERNAME`, `DOCKER_PASSWORD`

### 3. Credentials Base de Données

- `bdd_user1` à `bdd_user4` : Utilisateurs de la base de données
  - Type : Username/Password
  - Variables : `BDD_USERx_USERNAME`, `BDD_USERx_PASSWORD`

- `bdd_user_admin` : Administrateur de la base de données
  - Type : Username/Password
  - Variables : `BDD_USER_ADMIN_USERNAME`, `BDD_USER_ADMIN_PASSWORD`

### 4. Credentials GitHub

- `github-hebergement` : Accès au dépôt d'hébergement
  - Type : Username/Password
  - Variables : `GITHUB_USERNAME`, `GITHUB_TOKEN`

### 5. Credentials OVH DNS

- `OVH_DNS_ZONE` : Zone DNS OVH
  - Type : Secret text
  - Variable : `OVH_DNS_ZONE`

- `OVH_DNS_SUBDOMAIN` : Sous-domaine OVH
  - Type : Secret text
  - Variable : `OVH_DNS_SUBDOMAIN`

## Configuration

1. Créer un fichier `.env` à partir du modèle `.env.example`
2. Remplir toutes les variables avec les valeurs appropriées
3. Redémarrer Jenkins pour appliquer les changements

## Sécurité

- Ne jamais commiter le fichier `.env` dans le dépôt
- Utiliser des tokens avec les permissions minimales nécessaires
- Faire une rotation régulière des credentials
- Sauvegarder les credentials de manière sécurisée

## Vérification

Pour vérifier que tous les credentials sont correctement configurés :

1. Aller dans Jenkins > Manage Jenkins > Credentials
2. Vérifier que tous les credentials listés ci-dessus sont présents
3. Tester le pipeline avec `Build with Parameters`

## Dépannage

Si des erreurs de credentials apparaissent :

1. Vérifier que le fichier `.env` contient toutes les variables
2. Vérifier que les noms des credentials correspondent exactement
3. Vérifier les permissions des tokens
4. Consulter les logs Jenkins pour plus de détails