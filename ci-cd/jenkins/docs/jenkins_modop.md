# Guide de Configuration et Utilisation de Jenkins

## Table des matières
1. [Configuration initiale](#configuration-initiale)
2. [Lancement de Jenkins](#lancement-de-jenkins)
3. [Configuration as Code (CasC)](#configuration-as-code-casc)
4. [Configuration Spécifique: Connexion GitLab (Script Groovy)](#configuration-spécifique-connexion-gitlab-script-groovy)
5. [Fichiers de Configuration Spécifiques](#fichiers-de-configuration-spécifiques)
6. [Vérification via scripts](#vérification-via-scripts)
7. [Vérification via l'interface](#vérification-via-linterface)
8. [Intégration avec les projets existants](#intégration-avec-les-projets-existants)
9. [Gestion du mot de passe Administrateur (Problème CasC)](#gestion-du-mot-de-passe-administrateur-problème-casc)
10. [Intégration du dépôt d'hébergement GitHub avec Jenkins](#intégration-du-dépôt-d'hébergement-github-avec-jenkins)

## Configuration initiale

### 1. Structure des répertoires
```bash
hebergement_serveur/
└── ci-cd/
    └── jenkins/
        ├── casc/                   # Configuration as Code
        │   ├── jenkins.yaml        # Configuration principale CasC
        │   └── init.groovy.d/    # Scripts d'initialisation Groovy
        │       └── gitlab-config.groovy # Script pour configurer GitLab
        ├── data/                   # Données persistantes Jenkins (via volume Docker)
        ├── docs/                   # Documentation (ce fichier)
        │   └── jenkins_modop.md
        ├── scripts/                # Scripts utilitaires (ex: check-configuration.sh)
        ├── plugins.txt             # Liste des plugins Jenkins à installer
        └── docker-compose.yml      # Configuration Docker Compose
```
*(Note: Structure mise à jour pour inclure `init.groovy.d`)*

### 2. Configuration des variables d'environnement
Utilisez le fichier `.env` existant du projet et ajoutez/vérifiez les variables Jenkins :

```bash
# .env (extrait pertinent pour Jenkins)
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=votre_mot_de_passe_securise
# Note: Voir section "Gestion du mot de passe Administrateur"

# GITLAB_API_TOKEN est crucial pour CasC (credentials) et le script Groovy
GITLAB_API_TOKEN=votre_token_gitlab_personnel_avec_scope_api

DOCKER_USERNAME=votre_user_docker_hub
DOCKER_PASSWORD=votre_password_docker_hub

# Variable optionnelle pour l'authentification basique devant Traefik si activée
# JENKINS_BASIC_AUTH=resultat_du_hash_htpasswd
```

#### 1.1 Création du Token GitLab (`GITLAB_API_TOKEN`)
Si vous n'en avez pas :
- Connectez-vous à GitLab.
- Allez dans `Profil` > `Edit profile` > `Access Tokens`.
- Créez un token (`Nom`: jenkins-integration, `Expiration`: date lointaine, `Scopes`: **api**).
- **Copiez le token immédiatement** et placez-le dans `.env`.

## Lancement de Jenkins

### 1. Prérequis
- Docker et Docker Compose installés.
- Fichier `.env` correctement configuré.
- Le réseau externe `traefik-public` doit exister (`docker network create traefik-public` si ce n'est pas déjà fait par une autre stack).

### 2. Démarrage du service

copie des fichiers sur le serveur

```bash
 scp -i "ssh/airquality_server_key" .env INSTALL_SERVEUR.md install_server.sh pre-requis.sh configure_ovh_dns.sh .ovhconfig debug_install.md user@192.168.1.134:/hebergement_serveur/ ;
 scp -i ".\ssh\airquality_server_key" -r "ansible/" user@192.168.1.134:/hebergement_serveur ;
 scp -i ".\ssh\airquality_server_key" -r "ci-cd/" user@192.168.1.134:/hebergement_serveur ;
 scp -i ".\ssh\airquality_server_key" -r "reverse-proxy/" user@192.168.1.134:/hebergement_serveur
```

1.  **Se placer dans le répertoire Jenkins** :
    ```bash
    cd /hebergement_serveur/ci-cd/jenkins
    ```
2.  **Démarrer Jenkins (et Traefik si nécessaire)** :
    ```bash
    # Créer le volume nommé s'il n'existe pas
    docker volume create jenkins_data

    # Démarrer Jenkins (en arrière-plan)
    docker-compose up -d
    ```
3.  **Vérifier le démarrage des conteneurs** :
    ```bash
    docker-compose ps
    # S'assurer que le conteneur 'jenkins' est 'Up'
    ```
4.  **Suivre les logs (important pour la première fois et le debug)** :
    ```bash
    docker-compose logs -f jenkins
    ```
    Recherchez les messages indiquant :
    - Le chargement de la configuration CasC (`INFO    io.jenkins.plugins.casc.ConfigurationAsCode#configure: Configuring Jenkins from configuration sources...`)
    - L'exécution du script Groovy (`INFO    hudson.init.impl.GroovyInitScript#run: Running script: /var/jenkins_home/init.groovy.d/gitlab-config.groovy`)
    - Les messages `[Groovy Init]` indiquant la configuration de GitLab par le script.
    - La ligne finale `INFO    hudson.lifecycle.Lifecycle#onReady: Jenkins is fully up and running`.

### 3. Permissions (Si problème au premier démarrage)
Si Jenkins échoue au premier démarrage avec des erreurs de permission sur `/var/jenkins_home`, cela peut être dû au fait que le volume `jenkins_data` a été créé implicitement par Docker avec des permissions `root`. Pour corriger :
1.  Arrêtez Jenkins : `docker-compose down`
2.  **Supprimez UNIQUEMENT le volume de données** (attention, efface les données Jenkins existantes) : `docker volume rm jenkins_data`
3.  Recréez le volume explicitement : `docker volume create jenkins_data`
4.  Redémarrez : `docker-compose up -d`. L'image Jenkins devrait initialiser le volume avec les bonnes permissions (utilisateur `jenkins`, UID 1000 par défaut).

## Configuration as Code (CasC)

### 1. Principe
Jenkins est configuré principalement via des fichiers YAML grâce au plugin `Configuration-as-Code`. Le fichier principal est `casc/jenkins.yaml`. CasC configure :
- Les paramètres système de base.
- Le Realm de sécurité (ici, base de données locale Jenkins).
- Les **Credentials** (tokens, mots de passe) stockés de manière sécurisée.
- Les outils (ex: Git).
- Potentiellement les jobs (ici, nous utilisons un Job DSL via un script Groovy séparé chargé par CasC).
- Les configurations globales de certains plugins (ex: `logging`).

### 2. Fichier `casc/jenkins.yaml` (Structure simplifiée)
```yaml
jenkins:
  systemMessage: "Jenkins configuré via Configuration as Code"
  securityRealm:
    local:
      allowsSignup: false
      # NOTE: Section 'users' commentée - Voir section "Gestion du mot de passe Administrateur"

credentials:
  system:
    domainCredentials:
      - credentials:
          # Token GitLab (utilisé par le script Groovy et potentiellement les jobs)
          - gitLabApiTokenImpl:
              scope: SYSTEM
              id: "gitlab-token"
              apiToken: ${GITLAB_API_TOKEN}
              description: "GitLab API Token (pour connexion globale et jobs)"
          # Autres credentials (Docker Hub, SSH, etc.)
          - usernamePassword:
              scope: SYSTEM
              id: "docker-hub"
              username: ${DOCKER_USERNAME}
              password: ${DOCKER_PASSWORD}
              description: "Docker Hub Credentials"
          # ... autres credentials ...

tool:
  git:
    installations:
      - name: Default
        home: git # 'git' est suffisant si git est dans le PATH de l'image Jenkins

# Section 'jobs' : Charge les définitions de jobs depuis des fichiers groovy
# jobs:
#   - file: /var/jenkins_config/jobs/mon-pipeline.groovy

# Section 'unclassified' : Configuration spécifique de plugins
# NOTE: La configuration GitLab est commentée ici car gérée par script Groovy
# unclassified:
#   gitlabConnectionConfig:
#     connections:
#       - name: "GitLab"
#         # ... autres paramètres ...

# Section 'logging' : Configuration fine des logs pour le débogage
logging:
  loggers:
    'io.jenkins.plugins.casc': FINEST # Très verbeux pour CasC
    'com.dabsquared.gitlabjenkins': FINEST # Très verbeux pour le plugin GitLab
    'com.cloudbees.plugins.credentials': FINE # Pour le suivi des credentials
```

### 3. Rechargement de la configuration
Après une modification de `jenkins.yaml` (ou des scripts chargés par CasC), vous pouvez appliquer les changements sans redémarrer complètement Jenkins :
- Allez dans `Administrer Jenkins` > `Configuration as Code`.
- Cliquez sur `Appliquer la nouvelle configuration`.
- Surveillez les logs pour les erreurs éventuelles.

## Configuration Spécifique: Connexion GitLab (Script Groovy)

### 1. Problème rencontré
La configuration de la connexion globale GitLab via CasC (section `unclassified.gitlabConnectionConfig`) présente un bug : les paramètres de timeout (`connectionTimeout`, `readTimeout`) et `clientBuilderId` ne sont pas correctement initialisés, menant à des erreurs `NullPointerException` lors de l'utilisation de la connexion (ex: test de connexion, webhooks).

### 2. Solution : Script d'Initialisation Groovy
Pour contourner ce problème tout en gardant une configuration automatisée, un script Groovy est exécuté au démarrage de Jenkins :
- **Fichier :** `casc/init.groovy.d/gitlab-config.groovy`
- **Mécanisme :** Jenkins exécute tous les scripts `.groovy` dans `/var/jenkins_home/init.groovy.d/` au démarrage.
- **Montage Docker :** Le `docker-compose.yml` monte le répertoire local `./casc/init.groovy.d` vers `/var/jenkins_home/init.groovy.d/` dans le conteneur.

### 3. Contenu et fonctionnement du script (`gitlab-config.groovy`)
```groovy
import jenkins.model.*
import com.dabsquared.gitlabjenkins.connection.GitLabConnection
import com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig

// Configuration souhaitée (doit être cohérente avec CasC pour les credentials)
def gitlabConnectionName = "GitLab"
def gitlabUrl = "https://gitlab.com"
def gitlabApiTokenId = "gitlab-token" // ID du credential défini dans jenkins.yaml
def clientBuilderId = "autodetect"
def connectionTimeoutMillis = 10000 // 10 secondes
def readTimeoutMillis = 10000       // 10 secondes

Jenkins jenkins = Jenkins.get()
GitLabConnectionConfig gitlabConfig = jenkins.getDescriptorByType(GitLabConnectionConfig.class)

// Évite de recréer la connexion à chaque redémarrage
boolean connectionExists = gitlabConfig.getConnections().any { it.getName() == gitlabConnectionName }

if (!connectionExists) {
    println "--> [Groovy Init] Configuration de la connexion GitLab '${gitlabConnectionName}'..."
    GitLabConnection connection = new GitLabConnection(gitlabConnectionName)
    connection.setUrl(gitlabUrl)
    connection.setApiTokenId(gitlabApiTokenId) // Utilise le credential CasC
    connection.setClientBuilderId(clientBuilderId)
    connection.setConnectionTimeout(connectionTimeoutMillis) // Définit le timeout
    connection.setReadTimeout(readTimeoutMillis)         // Définit le timeout
    connection.setIgnoreCertificateErrors(false)

    List<GitLabConnection> connections = new ArrayList<>(gitlabConfig.getConnections())
    connections.add(connection)
    gitlabConfig.setConnections(connections)
    gitlabConfig.save()
    jenkins.save()
    println "--> [Groovy Init] Connexion GitLab '${gitlabConnectionName}' configurée."
} else {
    println "--> [Groovy Init] Connexion GitLab '${gitlabConnectionName}' existe déjà."
}
return
```

### 4. Interaction avec CasC
- La section `unclassified.gitlabConnectionConfig` **doit rester commentée** dans `jenkins.yaml`.
- Le credential GitLab (`gitlab-token`) **doit être défini** dans `jenkins.yaml` car le script Groovy s'y réfère par son ID.

## Fichiers de Configuration Spécifiques

### 1. Configuration Git (`git-config.xml`)

#### Objectif
Le fichier `git-config.xml` est utilisé pour configurer globalement Git dans Jenkins, en particulier pour résoudre les problèmes de sécurité liés aux répertoires de travail Git.

#### Structure et Fonctionnement
```xml
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>Configuration Git globale pour Jenkins</description>
  <scm class="hudson.plugins.git.GitSCMSource">
    <traits>
      <hudson.plugins.git.traits.BranchDiscoveryTrait/>
      <hudson.plugins.git.traits.TagDiscoveryTrait/>
      <jenkins.plugins.git.traits.CleanBeforeCheckoutTrait/>
      <jenkins.plugins.git.traits.CleanCheckoutTrait/>
      <jenkins.plugins.git.traits.CloneOptionTrait>
        <extension>
          <shallow>true</shallow>
          <noTags>true</noTags>
          <depth>1</depth>
          <timeout>10</timeout>
        </extension>
      </jenkins.plugins.git.traits.CloneOptionTrait>
    </traits>
  </scm>
  <builders>
    <hudson.tasks.Shell>
      <command>git config --global --add safe.directory /var/jenkins_home/workspace/applications/airquality/build-and-deploy@script/*</command>
    </hudson.tasks.Shell>
  </builders>
</project>
```

#### Pourquoi ce fichier ?
1. **Sécurité Git** : Git 2.35+ introduit des vérifications de sécurité strictes pour les répertoires de travail. Ce fichier configure explicitement les répertoires sûrs.
2. **Configuration Globale** : Assure une configuration Git cohérente pour tous les jobs Jenkins.
3. **Optimisation des Clones** : Configure des options de clone optimisées (shallow, no-tags) pour améliorer les performances.

### 2. Configuration Docker (`docker-config.json`)

#### Objectif
Le fichier `docker-config.json` gère l'authentification Docker de manière sécurisée dans Jenkins, évitant les problèmes de TTY et les risques de sécurité liés aux credentials en ligne de commande.

#### Structure et Fonctionnement
```json
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "${DOCKER_AUTH}"
    }
  },
  "HttpHeaders": {
    "User-Agent": "Docker-Client/19.03.13 (linux)"
  }
}
```

#### Pourquoi ce fichier ?
1. **Sécurité des Credentials** : Évite d'exposer les credentials Docker dans les commandes shell ou les logs.
2. **Résolution des Problèmes TTY** : Contourne l'erreur "Cannot perform an interactive login from a non TTY device" en utilisant une authentification basée sur fichier.
3. **Gestion Centralisée** : Permet une gestion centralisée des configurations Docker pour tous les jobs.

### 3. Intégration dans le Pipeline

#### Utilisation dans Jenkinsfile
```groovy
environment {
    DOCKER_CONFIG = "${WORKSPACE}/.docker"
    DOCKER_AUTH = credentials('dockerhub_airquality')
}

steps {
    script {
        // Configuration Docker sécurisée
        sh """
            mkdir -p ${DOCKER_CONFIG}
            cp ${WORKSPACE}/hebergement_serveur/ci-cd/jenkins/casc/docker-config.json ${DOCKER_CONFIG}/config.json
            chmod 600 ${DOCKER_CONFIG}/config.json
        """
    }
}
```

#### Bonnes Pratiques
1. **Permissions** : Toujours définir les permissions appropriées (600) sur les fichiers de configuration.
2. **Nettoyage** : Supprimer les fichiers sensibles après utilisation.
3. **Variables d'Environnement** : Utiliser des variables d'environnement pour les valeurs sensibles.
4. **Versioning** : Ne pas versionner les fichiers contenant des credentials.

### 4. Maintenance et Mise à Jour

#### Procédure de Mise à Jour
1. Modifier les fichiers de configuration dans le répertoire `casc/`.
2. Redémarrer Jenkins ou recharger la configuration via l'interface.
3. Vérifier les logs pour s'assurer que les configurations sont correctement appliquées.

#### Surveillance
- Surveiller les logs Jenkins pour détecter d'éventuels problèmes d'authentification.
- Vérifier régulièrement que les configurations sont toujours valides.
- Maintenir à jour les versions des clients Docker et Git.

## Vérification via scripts

*(Cette section reste globalement inchangée, mais le script `check-configuration.sh` devrait idéalement tester la connexion GitLab en utilisant l'API Jenkins ou en déclenchant une action qui l'utilise)*

### 1. Vérification de la configuration
```bash
# Exécuter depuis le répertoire hebergement_serveur/ci-cd/jenkins
./scripts/check-configuration.sh
```
Le script devrait vérifier (liste indicative) :
- Les variables d'environnement requises (`GITLAB_API_TOKEN`, etc.).
- L'accessibilité de l'URL Jenkins.
- La présence et la validité du credential `gitlab-token` (potentiellement via l'API Jenkins si le script est avancé).
- La connexion à Docker Hub (si nécessaire).

### 2. Résolution des problèmes courants
- Si une variable est manquante : vérifiez `.env`.
- Si Jenkins n'est pas accessible : `docker-compose logs jenkins`. Vérifiez les erreurs CasC ou Groovy au démarrage.
- Si la connexion GitLab échoue (dans l'interface ou les jobs) :
    - Vérifiez les logs du script `[Groovy Init]`.
    - Assurez-vous que `GITLAB_API_TOKEN` dans `.env` est correct et a les bons scopes.
    - Vérifiez que le credential `gitlab-token` existe dans Jenkins (`Credentials`).

## Vérification via l'interface

### 1. Accès à l'interface
- URL : `https://jenkins.iaproject.fr` (ou l'URL définie par Traefik)
- Identifiants : Définis dans `.env` (et gérés manuellement après le 1er démarrage, voir section dédiée).

### 2. Points de vérification
1.  **Credentials :**
    - Menu : `Tableau de bord` > `Administrer Jenkins` > `Credentials`.
    - Système > Domaine global.
    - Vérifier la présence et la description de :
        *   `gitlab-token` (Type: GitLab API Token)
        *   `docker-hub` (Type: Username with password)
        *   Autres credentials définis dans `jenkins.yaml`.
2.  **Configuration Système - Connexion GitLab :**
    - Menu : `Tableau de bord` > `Administrer Jenkins` > `System`.
    - Chercher la section `GitLab`.
    - **Vérifier que la connexion "GitLab" est présente**, configurée avec l'URL `https://gitlab.com` et le credential `gitlab-token`.
    - **Cliquer sur "Test Connection"**. Le résultat doit être `Success`. *C'est le test clé pour valider la solution du script Groovy.*
3.  **Configuration as Code Status :**
    - Menu : `Tableau de bord` > `Administrer Jenkins` > `Configuration as Code`.
    - Vérifier qu'il n'y a pas d'erreurs affichées.
4.  **Logs système Jenkins :**
    - Menu : `Tableau de bord` > `Administrer Jenkins` > `System Log`.
    - Créer un logger personnalisé pour `init.groovy.d` ou vérifier les logs `All Jenkins Logs` pour les messages `[Groovy Init]` après un redémarrage.
5.  **Plugins Installés :**
    - Menu : `Tableau de bord` > `Administrer Jenkins` > `Plugins` > `Installed plugins`.
    - Vérifier la présence des plugins listés dans `plugins.txt` et de leurs dépendances (ex: `gitlab-plugin`, `configuration-as-code`, `workflow-aggregator`, `docker-workflow`, etc.).

## Intégration avec les projets existants

*(Cette section reste conceptuellement la même)*

### 1. Projet Qualité de l'Air
- Le pipeline est défini par le `Jenkinsfile` dans le dépôt `airquality`.
- Le job Jenkins correspondant est créé via un script DSL (`jobs/airquality-pipeline.groovy`) chargé par CasC (si la section `jobs:` est décommentée dans `jenkins.yaml`).
- **Credentials requis par le pipeline AirQuality** : Assurez-vous que les IDs des credentials définis dans `casc/jenkins.yaml` correspondent à ceux attendus par le `Jenkinsfile` (ex: `credentialGitlab`, `dockerhub_airquality`, `cle_ssh_vm_test`, `bdd_user*`).
- **Webhook GitLab** :
    - URL à configurer dans GitLab : `https://jenkins.iaproject.fr/project/applications/airquality/build-and-deploy` (ou l'URL spécifique du job si différente).
    - Le webhook doit pointer vers le job pipeline spécifique, pas le webhook global `/gitlab-webhook/`.
    - Triggers : Push events, Merge request events.
    - SSL verification : Enabled.

## Gestion du mot de passe Administrateur (Problème CasC)

*(Cette section reste importante et correcte)*

**Contexte :** La gestion de l'utilisateur admin via `securityRealm.local.users` dans CasC pose problème car Jenkins stocke le hash du mot de passe dans un fichier spécifique à l'utilisateur (`/var/jenkins_home/users/ID_UTILISATEUR/config.xml`) qui n'est pas correctement mis à jour par CasC après le premier démarrage.

**Solution :**
1.  **Commenter/Supprimer la section `users:`** dans `casc/jenkins.yaml` sous `securityRealm.local`.
    ```yaml
    # casc/jenkins.yaml
    jenkins:
      securityRealm:
        local:
          allowsSignup: false
          # users: # DOIT être commenté ou supprimé
          #   - id: ${JENKINS_ADMIN_ID}
          #     password: ${JENKINS_ADMIN_PASSWORD}
    ```
2.  **Gérer le mot de passe admin manuellement** via l'interface Jenkins (`Administrer Jenkins` > `Security` > `Manage Users` > `admin` > `Configure`) après le premier démarrage. Ce mot de passe manuel sera persistant.

## Dépannage des problèmes courants

*(Cette section remplace ou complète l'ancienne section "Résolution des problèmes courants" sous "Vérification via scripts")*

### Problème 1: Échec du "Test Connection" pour GitLab dans la configuration système

- **Symptômes :** Dans `Administrer Jenkins` > `System` > `GitLab`, cliquer sur "Test Connection" échoue, souvent avec une `NullPointerException` dans les logs Jenkins, ou des erreurs liées aux timeouts.
- **Cause :** Un bug connu dans la configuration de `unclassified.gitlabConnectionConfig` via CasC empêche la définition correcte des timeouts et d'autres paramètres essentiels.
- **Solution :**
    1.  **Ne PAS configurer** la connexion GitLab via `unclassified.gitlabConnectionConfig` dans `casc/jenkins.yaml` (laisser cette section commentée).
    2.  **Définir un credential GitLab API Token** dans `casc/jenkins.yaml` avec l'ID `gitlab-token` (type `gitLabApiTokenImpl`). Assurez-vous que la variable `${GITLAB_API_TOKEN}` est correcte dans `.env`.
        ```yaml
        # casc/jenkins.yaml (extrait)
        credentials:
          system:
            domainCredentials:
              - credentials:
                  - gitLabApiTokenImpl:
                      scope: SYSTEM
                      id: "gitlab-token"
                      apiToken: ${GITLAB_API_TOKEN}
                      description: "GitLab API Token (Standard Connection - via GitLab Token Type)"
                  # ... autres credentials ...
        ```
    3.  **Utiliser le script d'initialisation** `casc/init.groovy.d/gitlab-config.groovy` (monté dans le conteneur via `docker-compose.yml`). Ce script utilise le credential `gitlab-token` défini ci-dessus et configure la connexion GitLab correctement via l'API Jenkins au démarrage, en définissant les timeouts nécessaires.
    4.  **Vérifier** après redémarrage/rechargement :
        *   Les logs Jenkins pour les messages `[Groovy Init]` confirmant la configuration.
        *   Le test de connexion dans l'interface (`Administrer Jenkins` > `System` > `GitLab` > `Test Connection`) doit réussir.

### Problème 2: Erreur `HTTP Basic Access denied` lors du checkout SCM (clone/fetch) d'un dépôt GitLab via HTTPS dans un pipeline

- **Symptômes :** Le pipeline échoue dès le début lors de l'étape de checkout avec une erreur indiquant `Authentication failed` ou `HTTP Basic Access denied` pour l'URL `https://gitlab.com/...`.
- **Cause :** Le plugin Git SCM standard, lors d'un checkout via HTTPS, s'attend généralement à un credential de type `Username with password`. Le type `GitLab API Token` (`gitLabApiTokenImpl`), bien que fonctionnel pour l'API GitLab (utilisé par le plugin GitLab ou notre script Groovy), n'est pas toujours interprété correctement par le SCM Git pour l'opération de `clone` HTTPS. Git tente une authentification basique (utilisateur/mot de passe) qui échoue car GitLab attend un token pour ce type d'opération.
- **Solution :**
    1.  **Créer un credential spécifique pour le checkout SCM** dans `casc/jenkins.yaml`, en utilisant le type `usernamePassword` :
        ```yaml
        # casc/jenkins.yaml (extrait)
        credentials:
          system:
            domainCredentials:
              - credentials:
                  # ... (le gitlab-token de type gitLabApiTokenImpl reste pour la connexion globale) ...

                  # Credential SPÉCIFIQUE pour le checkout SCM via HTTPS
                  - usernamePassword:
                      scope: GLOBAL # Ou SYSTEM, GLOBAL est plus sûr pour la visibilité dans les jobs
                      id: "credentialGitlab" # ID spécifique pour ce credential SCM
                      username: "oauth2" # Nom d'utilisateur arbitraire, GitLab l'ignore pour les tokens PAT
                      password: ${GITLAB_API_TOKEN} # Le token GitLab est utilisé comme mot de passe
                      description: "GitLab Token (Username/Password pour checkout HTTPS)"
                  # ... autres credentials ...
        ```
    2.  **Configurer le Job/Pipeline :** Dans la configuration de votre pipeline Jenkins (section SCM ou `checkout scm`), sélectionnez explicitement le credential avec l'ID `credentialGitlab` (ou la description correspondante) pour l'URL de votre dépôt GitLab HTTPS.
    3.  **Vérifier :** Relancer le pipeline. Le checkout devrait maintenant utiliser ce credential `usernamePassword` (en passant le token comme mot de passe via `GIT_ASKPASS`), ce qui réussit l'authentification auprès de GitLab.

### Problème 3: Erreur `docker: not found` lors de l'exécution d'étapes Docker dans un pipeline

- **Symptômes :** Une étape `sh 'docker ...'` (par exemple `docker build`, `docker run`) dans un pipeline échoue avec `docker: not found`.
- **Cause 1 : Agent Inadapté :** L'agent Jenkins exécutant l'étape (par défaut, le contrôleur Jenkins si `agent any` est utilisé) n'a pas le client Docker (la commande `docker`) installé.
- **Cause 2 : Orchestration Agent Docker :** Même en utilisant `agent { docker { ... } }`, le *contrôleur Jenkins* a besoin du client `docker` pour interagir avec le démon Docker de l'hôte afin de lancer et gérer les conteneurs agents (`docker pull`, `docker run`, `docker inspect`). L'image Jenkins standard (`jenkins/jenkins:lts`) ne l'inclut pas.
- **Solution Combinée :**
    1.  **Utiliser des Agents Docker dédiés :** Pour les étapes nécessitant Docker, privilégier la syntaxe `agent { docker { image 'nom-image:tag' ... } }` dans le `Jenkinsfile` plutôt que `agent any`. Cela isole l'exécution Docker dans un conteneur dédié.
    2.  **Créer une Image Jenkins Personnalisée :** Pour que le contrôleur Jenkins puisse gérer les agents Docker, il a besoin du client Docker. Créez un `Dockerfile` (ex: `hebergement_serveur/ci-cd/jenkins/Dockerfile.jenkins`) basé sur l'image officielle (`jenkins/jenkins:lts`) et installez-y le client `docker-ce-cli`.
        ```dockerfile
        # hebergement_serveur/ci-cd/jenkins/Dockerfile.jenkins (exemple)
        FROM jenkins/jenkins:lts
        USER root
        RUN apt-get update && apt-get install -y --no-install-recommends curl apt-transport-https ca-certificates gnupg-agent software-properties-common && \
            curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
            add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable" && \
            apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
            apt-get clean && rm -rf /var/lib/apt/lists/*
        USER jenkins
        ```
    3.  **Construire l'Image Personnalisée :** Depuis le répertoire contenant ce Dockerfile, exécutez `docker build -t jenkins-avec-docker:latest -f Dockerfile.jenkins .` (adaptez le tag et le nom du fichier).
    4.  **Modifier `docker-compose.yml` :**
        *   Changer `image: jenkins/jenkins:lts` par `image: jenkins-avec-docker:latest` (ou le nom choisi).
        *   **S'assurer** que le socket Docker est monté : `- /var/run/docker.sock:/var/run/docker.sock`.
        *   **S'assurer** que Jenkins tourne en `root` pour les permissions sur le socket : `user: "root"`.
    5.  **Redémarrer Jenkins :** `docker-compose down && docker-compose up -d`.

### Problème 4: Erreur `Invalid agent type "docker" specified`

- **Symptômes :** Le pipeline échoue immédiatement lors de la déclaration d'un `agent { docker { ... } }`.
- **Cause :** Le plugin Jenkins requis, **Docker Pipeline** (ID: `docker-workflow`), n'est pas installé ou activé.
- **Solution :**
    1.  **Vérifier `plugins.txt` :** Assurez-vous que le fichier `hebergement_serveur/ci-cd/jenkins/plugins.txt` contient la ligne `docker-workflow:latest`.
    2.  **Redémarrer Jenkins :** Arrêtez et redémarrez Jenkins (`docker-compose down && docker-compose up -d`). Jenkins tentera d'installer les plugins listés au démarrage. Surveillez les logs.
    3.  **Vérifier via l'UI (si nécessaire) :** Allez dans `Administrer Jenkins` > `Plugins` > `Installed plugins`. Recherchez "Docker Pipeline". Assurez-vous qu'il est installé et coché (activé). S'il n'est pas installé malgré sa présence dans `plugins.txt`, vérifiez les logs de démarrage pour des erreurs d'installation (dépendances manquantes, etc.) et installez-le manuellement via l'onglet "Available plugins" si besoin, puis redémarrez.

### Problème 5: Build OK (étapes vertes) mais statut final Rouge (❌) et "End" non atteint

- **Symptômes :** Les étapes visibles dans le graphe du pipeline sont vertes, mais le statut global est échec.
- **Cause Possible : Échec de l'Agent :** Souvent, cela indique que Jenkins n'a pas réussi à provisionner ou utiliser l'agent spécifié pour les `stages` principaux (ex: l'agent `docker` n'a pas pu démarrer à cause de l'erreur `docker: not found` décrite au Problème 3). Les `stages` ne s'exécutent pas, Jenkins passe directement au bloc `post`, qui peut réussir (s'il utilise un agent différent ou aucune étape dépendante), mais l'échec de l'allocation de l'agent principal marque le build comme échoué.
- **Solution :** Consulter la **`Console Output`** complète du build pour identifier l'erreur exacte survenue après le checkout initial du `Jenkinsfile` et avant l'exécution des `stages` (voir Problème 3 et 4).

## Architecture Avancée: Pipeline de Construction d'Image Agent

**Raison d'être :** Plutôt que d'installer des outils (comme Ansible, Docker CLI, Terraform, etc.) manuellement sur les agents Jenkins ou d'utiliser des images génériques comme `docker:latest` qui peuvent manquer d'outils spécifiques, il est préférable de créer des **images Docker d'agent personnalisées**. Ces images contiennent précisément l'ensemble des outils requis pour un pipeline ou un stage donné. Pour éviter de construire et pousser ces images manuellement (ce qui est source d'erreurs et non reproductible), on automatise leur création via un pipeline CI/CD dédié.

**Approche Choisie (Pipeline Jenkins Dédié) :**
Pour éviter de surcharger les images agents standard ou de construire des images complexes à la volée, il est recommandé de créer des images d'agents personnalisées. Pour automatiser la création de ces images (ex: une image contenant Docker CLI et Ansible), un pipeline Jenkins dédié (`preparation_image_docker_ansible`) est mis en place via CasC :

1.  **Création du `Dockerfile` de l'Agent :**
    *   Placer un `Dockerfile` décrivant l'image agent personnalisée (ex: `projet_qualite_air/ansible/Dockerfile`).
2.  **Création du `Jenkinsfile` pour le Build de l'Image Agent :**
    *   Créer un `Jenkinsfile` spécifique (ex: `projet_qualite_air/ansible/Jenkinsfile.image-builder`) décrivant les étapes pour construire et pousser l'image agent vers un registre.
3.  **Définition du Job Jenkins via Job DSL (CasC) :**
    *   Dans `hebergement_serveur/ci-cd/jenkins/casc/jobs/`, créer un fichier `.groovy` (ex: `preparation_image_docker_ansible.groovy`) définissant le `pipelineJob` qui utilise le `Jenkinsfile.image-builder` et se déclenche sur les changements (ex: `pollSCM`).
4.  **Chargement du Job DSL via `jenkins.yaml` :**
    *   Référencer le fichier `.groovy` dans la section `jobs:` de `hebergement_serveur/ci-cd/jenkins/casc/jenkins.yaml`.
5.  **Utilisation dans le Pipeline Applicatif :**
    *   Le pipeline applicatif principal (`projet_qualite_air/ci-cd/Jenkinsfile`) utilise l'image pré-construite via `agent { docker { image 'votre-repo/nom-image-agent:latest' ... } }`.

**Alternatives Considérées :**
D'autres solutions existent pour automatiser la construction de l'image agent :
*   **GitLab CI/CD :** Définir un job dans `.gitlab-ci.yml` dans le dépôt `projet_qualite_air` qui construit et pousse l'image, déclenché par les modifications dans `ansible/Dockerfile`.
*   **Docker Hub Automated Builds :** Lier Docker Hub au dépôt GitLab pour que Docker Hub reconstruise automatiquement l'image lors de changements sur la branche spécifiée.
L'approche avec un pipeline Jenkins dédié a été choisie pour centraliser la logique CI/CD au sein de Jenkins.

**Avantages de l'Automatisation :**
*   Environnements d'agents reproductibles et versionnés.
*   Pipelines applicatifs plus simples.
*   Construction des outils découplée de l'exécution applicative.
*   Mises à jour des outils gérées via Git et CI.

## Bonnes pratiques

*(Ajout ou renforcement de points spécifiques)*

1.  **Gestion des secrets :** Utiliser les credentials Jenkins gérés par CasC. Pour des secrets plus complexes ou partagés, envisager HashiCorp Vault avec le plugin Jenkins Vault. **Ne jamais coder en dur de secrets** dans `jenkins.yaml`, les scripts Groovy, ou les Jenkinsfiles (utiliser les variables d'environnement via `.env` pour CasC/Docker Compose).
2.  **Sauvegarde :** Sauvegarder régulièrement le volume Docker `jenkins_data`. Versionner (`git`) l'intégralité du répertoire de configuration Jenkins (`hebergement_serveur/ci-cd/jenkins`), incluant `casc/`, `scripts/`, `plugins.txt`, `docker-compose.yml`, et `docs/`.
3.  **Monitoring :** Utiliser des plugins comme `Prometheus Metrics` pour exposer des métriques. Surveiller l'utilisation disque du volume `jenkins_data`.
4.  **Documentation :** Maintenir ce fichier `jenkins_modop.md` à jour.
5.  **Tests de la configuration :** Utiliser `./scripts/check-configuration.sh` (ou un équivalent) après chaque modification majeure. Tester manuellement les points clés dans l'interface (connexion GitLab, exécution d'un job simple).

## Intégration du dépôt d'hébergement GitHub avec Jenkins

### 1. Contexte et Objectif

Le dépôt d'hébergement (`hebergement_serveur`) est hébergé sur GitHub ([lien](https://github.com/bigmoletos/hebergement_serveur.git)), tandis que le projet applicatif principal est sur GitLab. Pour garantir la cohérence, l'automatisation et la traçabilité des changements d'infrastructure, il est essentiel de déclencher automatiquement des builds Jenkins à chaque modification du dépôt d'hébergement.

### 2. Pourquoi mettre en place un webhook GitHub ?

- **Automatisation** : Chaque commit/push sur le dépôt GitHub déclenche automatiquement un pipeline Jenkins, assurant l'application immédiate des changements de configuration.
- **Sécurité** : L'utilisation d'un secret pour le webhook garantit que seuls les événements authentifiés de GitHub sont acceptés par Jenkins.
- **Traçabilité** : Les modifications d'infrastructure sont historisées et auditées via GitHub et Jenkins.

### 3. Mise en place du webhook GitHub

#### a. Génération du secret webhook

Un secret sécurisé est généré (exemple : `openssl rand -hex 20`) et stocké dans le fichier `.env` sous la variable :
```
GITHUB_WEBHOOK_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### b. Configuration du webhook dans GitHub

- Aller dans **Settings > Webhooks** du dépôt GitHub.
- Cliquer sur **Add webhook**.
- **Payload URL** : `https://jenkins.iaproject.fr/github-webhook/`
- **Content type** : `application/json`
- **Secret** : (le secret généré ci-dessus)
- **Events** : sélectionner uniquement "Just the push event".
- Valider.
- Vérifier que "Last delivery was successful" s'affiche (✓ vert).

#### c. Configuration côté Jenkins

- Ajout du credential GitHub dans `jenkins.yaml` :
    ```yaml
    - usernamePassword:
        scope: GLOBAL
        id: "github-hebergement"
        username: ${GITHUB_USER}
        password: ${GITHUB_PASSWORD}
        description: "GitHub Credentials pour le dépôt d'hébergement"
    ```
- Ajout de la configuration webhook dans la section `unclassified` :
    ```yaml
    githubConfiguration:
      configs:
        - name: "GitHub"
          apiUrl: "https://api.github.com"
          credentialsId: "github-hebergement"
          manageHooks: true

    githubWebhookConfiguration:
      webhookSecretConfigs:
        - webhookSecretId: "github-webhook-secret"
          webhookSecret: ${GITHUB_WEBHOOK_SECRET}
    ```

#### d. Création du pipeline d'hébergement

- **Job DSL** : `casc/jobs/hebergement-pipeline.groovy`
    - Surveille le dépôt GitHub.
    - Utilise le credential `github-hebergement`.
    - Déclencheur : `githubPush()`.
    - Utilise le fichier `ci-cd/jenkins/Jenkinsfile.hebergement` pour la logique du pipeline.

- **Jenkinsfile dédié** : `ci-cd/jenkins/Jenkinsfile.hebergement`
    - Valide la syntaxe des fichiers YAML et Groovy.
    - Applique la configuration Jenkins si des fichiers de config ont changé.
    - Met à jour les services Docker si besoin.

#### e. Pourquoi cette architecture ?

- **Séparation claire** entre la logique d'hébergement (infrastructure, Jenkins, scripts) et la logique applicative (projet GitLab).
- **Sécurité** : chaque dépôt a son propre secret et ses propres credentials.
- **Scalabilité** : possibilité d'ajouter d'autres dépôts d'infrastructure ou de monitoring avec la même logique.

### 4. Bonnes pratiques

- **Ne jamais exposer le secret webhook** dans les scripts ou dans le code source.
- **Vérifier régulièrement** le statut du webhook dans GitHub.
- **Documenter** toute modification de la configuration Jenkins ou du pipeline d'hébergement.

### 5. Test du webhook

1. Faire un commit/push sur le dépôt GitHub `hebergement_serveur`.
2. Vérifier dans GitHub que le webhook est bien déclenché (section "Recent Deliveries").
3. Vérifier dans Jenkins que le pipeline `infrastructure/hebergement/config-update` est lancé automatiquement.
4. Consulter les logs Jenkins pour s'assurer que les étapes de validation et d'application de la configuration se déroulent sans erreur.

---

**Résumé** :
La mise en place du webhook GitHub permet d'automatiser la gestion de l'infrastructure Jenkins à chaque modification du dépôt d'hébergement, tout en garantissant sécurité, traçabilité et bonnes pratiques DevOps.