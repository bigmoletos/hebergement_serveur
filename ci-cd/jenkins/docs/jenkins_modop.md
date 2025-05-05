# Guide de Configuration et Utilisation de Jenkins

## Table des matières
1. [Configuration initiale](#configuration-initiale)
2. [Lancement de Jenkins](#lancement-de-jenkins)
3. [Configuration as Code (CasC)](#configuration-as-code-casc)
4. [Configuration Spécifique: Connexion GitLab (Script Groovy)](#configuration-spécifique-connexion-gitlab-script-groovy)
5. [Vérification via scripts](#vérification-via-scripts)
6. [Vérification via l'interface](#vérification-via-linterface)
7. [Intégration avec les projets existants](#intégration-avec-les-projets-existants)
8. [Gestion du mot de passe Administrateur (Problème CasC)](#gestion-du-mot-de-passe-administrateur-problème-casc)

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

## Bonnes pratiques

*(Ajout ou renforcement de points spécifiques)*

1.  **Gestion des secrets :** Utiliser les credentials Jenkins gérés par CasC. Pour des secrets plus complexes ou partagés, envisager HashiCorp Vault avec le plugin Jenkins Vault. **Ne jamais coder en dur de secrets** dans `jenkins.yaml`, les scripts Groovy, ou les Jenkinsfiles (utiliser les variables d'environnement via `.env` pour CasC/Docker Compose).
2.  **Sauvegarde :** Sauvegarder régulièrement le volume Docker `jenkins_data`. Versionner (`git`) l'intégralité du répertoire de configuration Jenkins (`hebergement_serveur/ci-cd/jenkins`), incluant `casc/`, `scripts/`, `plugins.txt`, `docker-compose.yml`, et `docs/`.
3.  **Monitoring :** Utiliser des plugins comme `Prometheus Metrics` pour exposer des métriques. Surveiller l'utilisation disque du volume `jenkins_data`.
4.  **Documentation :** Maintenir ce fichier `jenkins_modop.md` à jour.
5.  **Tests de la configuration :** Utiliser `./scripts/check-configuration.sh` (ou un équivalent) après chaque modification majeure. Tester manuellement les points clés dans l'interface (connexion GitLab, exécution d'un job simple).