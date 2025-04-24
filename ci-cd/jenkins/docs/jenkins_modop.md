# Guide de Configuration et Utilisation de Jenkins

## Table des matières
1. [Configuration initiale](#configuration-initiale)
2. [Lancement de Jenkins](#lancement-de-jenkins)
3. [Configuration as Code](#configuration-as-code)
4. [Vérification via scripts](#vérification-via-scripts)
5. [Vérification via l'interface](#vérification-via-linterface)
6. [Intégration avec les projets existants](#intégration-avec-les-projets-existants)

## Configuration initiale

### 1. Structure des répertoires
```bash
hebergement_serveur/
└── ci-cd/
    └── jenkins/
        ├── casc/              # Configuration as Code
        │   └── jenkins.yaml   # Configuration principale
        ├── data/              # Données persistantes Jenkins
        ├── scripts/           # Scripts utilitaires
        └── docker-compose.yml # Configuration Docker
```

### 2. Configuration des variables d'environnement
Utilisez le fichier `.env` existant du projet et ajoutez les variables Jenkins :

```bash
# Ajoutez dans le fichier .env existant :
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=votre_mot_de_passe_securise

# Générez le hash pour l'authentification basique
docker run --rm httpd:2.4-alpine htpasswd -nb admin votre_mot_de_passe | sed -e s/\\$/\\$\\$/g
# Ajoutez le résultat comme JENKINS_BASIC_AUTH
```

## Lancement de Jenkins

### 1. Prérequis
- Docker et Docker Compose installés
- Fichier `.env` configuré avec les variables requises :
  ```bash
  JENKINS_ADMIN_USER=admin
  JENKINS_ADMIN_PASSWORD=votre_mot_de_passe_securise
  JENKINS_BASIC_AUTH=resultat_du_hash_htpasswd
  GITLAB_API_TOKEN=votre_token_gitlab
  DOCKER_USERNAME=votre_user_docker
  DOCKER_PASSWORD=votre_password_docker


#### 1.1 Pour créer le hash de JENKINS_BASIC_AUTH
  ```bash
  # commande linux
  docker run --rm httpd:2.4-alpine htpasswd -nb admin votre_mot_de_passe | sed -e s/\\$/\\$\\$/g
  # commande windows powershell
  docker run --rm httpd:2.4-alpine htpasswd -nb votre_user votre_mot_de_passe
  ```

#### 1.2 Pour GITLAB_API_TOKEN

Connectez-vous à votre compte GitLab :

- Allez dans votre profil (icône en haut à droite)

- Cliquez sur "Edit profile"

- Dans le menu de gauche, cliquez sur "Access Tokens"
- Créez un nouveau token :
- Nom : jenkins-integration
- Expiration : choisissez une date appropriée
- Scopes :
- api (accès complet à l'API)
- read_repository (lecture des dépôts)
- write_repository (écriture dans les dépôts)
- Cliquez sur "Create personal access token"
- IMPORTANT : Copiez immédiatement le token généré, il ne sera plus visible après
- Ensuite, ajoutez ces valeurs dans votre fichier .env :

### 2. Démarrage du service
1. **Se placer dans le répertoire Jenkins** :
   ```bash
   cd /hebergement_serveur/ci-cd/jenkins
   ```

2. **Vérifier la configuration** :
   ```bash
   # Vérifier le fichier docker-compose.yml
   cat docker-compose.yml

   # Vérifier la présence des variables d'environnement
   set | grep JENKINS_
   ```

3. **Lancer Jenkins** :

   ```bash
   # Démarrer le service
   docker-compose up -d

   # Vérifier que le conteneur est bien démarré
   docker-compose ps

   # Suivre les logs pour vérifier le démarrage
   docker-compose logs -f jenkins

   # donner les bonnes permissions au dossier data
   mkdir -p data && sudo chown -R 1000:1000 data
   ```

### 3. Vérification du démarrage
1. **Vérifier l'accès web** :
   - Ouvrir https://jenkins.iaproject.fr dans un navigateur
   - Se connecter avec les identifiants définis dans `.env`

2. **Vérifier les services** :
   ```bash
   # Tester la connexion à GitLab
   ./scripts/check-configuration.sh

   # Vérifier les logs en cas d'erreur
   docker-compose logs jenkins | grep -i error
   ```

### 4. Arrêt et redémarrage
```bash
# Arrêter Jenkins
docker-compose down

# Redémarrer Jenkins
docker-compose up -d

# Arrêter et supprimer les volumes (attention : perte des données)
docker-compose down -v
```

### 5. Résolution des problèmes courants
1. **Jenkins ne démarre pas** :
   - Vérifier les logs : `docker-compose logs jenkins`
   - Vérifier les permissions du dossier `data/`
   - Vérifier que les ports ne sont pas déjà utilisés

2. **Erreur d'authentification** :
   - Vérifier les variables dans `.env`
   - Regénérer le hash d'authentification basique
   - Vérifier les logs de connexion

3. **Webhook GitLab non fonctionnel** :
   - Vérifier la configuration SSL
   - Vérifier l'accessibilité de l'URL
   - Tester manuellement le webhook

## Configuration as Code

### 1. Configuration principale (jenkins.yaml)
```yaml
jenkins:
  systemMessage: "Jenkins configuré via Configuration as Code"
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: ${JENKINS_ADMIN_ID}
          password: ${JENKINS_ADMIN_PASSWORD}

credentials:
  system:
    domainCredentials:
      - credentials:
          - gitLabApiTokenImpl:
              id: "gitlab-token"
              apiToken: ${GITLAB_API_TOKEN}
```

### 2. Démarrage de Jenkins
```bash
cd /hebergement_serveur/ci-cd/jenkins
docker-compose up -d
```

## Vérification via scripts

### 1. Vérification de la configuration
```bash
./scripts/check-configuration.sh
```

Le script vérifie :
- Les variables d'environnement requises
- L'accès à Jenkins
- La connexion à GitLab
- La connexion à Docker Hub
- La configuration des webhooks

### 2. Résolution des problèmes courants
- Si une variable est manquante : vérifiez le fichier .env
- Si Jenkins n'est pas accessible : vérifiez les logs avec `docker-compose logs jenkins`
- Si le webhook échoue : vérifiez les permissions GitLab

## Vérification via l'interface

### 1. Accès à l'interface
- URL : https://jenkins.iaproject.fr
- Identifiants : définis dans le fichier .env

### 2. Points de vérification
1. **Credentials**
   - Menu : Jenkins > Credentials
   - Vérifier la présence de :
     * gitlab-token
     * docker-hub

2. **Configuration système**
   - Menu : Jenkins > Manage Jenkins > Configure System
   - Vérifier :
     * GitLab Connection
     * Security settings

3. **Plugins**
   - Menu : Jenkins > Manage Jenkins > Plugins
   - Plugins requis :
     * GitLab Plugin
     * Docker Pipeline
     * Configuration as Code

### 3. Test manuel des connexions
1. **Test GitLab** :
   - Menu : Jenkins > Manage Jenkins > Configure System
   - Section GitLab
   - Bouton "Test Connection"

2. **Test Docker Hub** :
   - Créez un job test
   - Pipeline script :
   ```groovy
   node {
       withCredentials([usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
           sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
       }
   }
   ```

## Intégration avec les projets existants

### 1. Projet Qualité de l'Air
Le projet dispose déjà de son propre pipeline Jenkins. Pour l'intégrer :

1. **Ne pas créer de nouveau pipeline**
   - Utiliser le Jenkinsfile existant
   - Conserver la configuration existante

2. **Mise à jour des credentials**
   - Copier les credentials nécessaires depuis l'ancien Jenkins
   - Utiliser les mêmes IDs de credentials pour assurer la compatibilité

3. **Configuration du webhook**
   ```bash
   # URL du webhook
   https://jenkins.iaproject.fr/gitlab-webhook/

   # Dans GitLab : Settings > Webhooks
   # - URL: https://jenkins.iaproject.fr/gitlab-webhook/
   # - Trigger: Push events, Merge request events
   # - SSL verification: Enabled
   ```

### 2. Bonnes pratiques
1. **Gestion des secrets**
   - Utiliser HashiCorp Vault pour les secrets
   - Ne jamais stocker de secrets dans les fichiers de configuration

2. **Sauvegarde**
   - Sauvegarder régulièrement le dossier `data/`
   - Versionner tous les fichiers de configuration

3. **Monitoring**
   - Configurer des alertes pour les échecs de build
   - Surveiller l'espace disque du volume Jenkins

4. **Documentation**
   - Maintenir ce guide à jour
   - Documenter toute modification de la configuration