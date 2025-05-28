# 🔐 Variables d'Environnement Required pour Jenkins CasC

## Vue d'ensemble

Ce fichier liste toutes les variables d'environnement nécessaires pour que Jenkins fonctionne correctement avec la configuration "Configuration as Code" (CasC).

Ces variables doivent être définies dans le fichier `.env` du projet **hébergement_serveur** et seront injectées dans le conteneur Jenkins au démarrage.

## Variables Required

### 🏗️ Jenkins Core
```bash
JENKINS_ADMIN_ID=admin
JENKINS_ADMIN_USER=admin
JENKINS_API_TOKEN=your_jenkins_api_token_here
```

### 🔗 GitLab Integration
```bash
GITLAB_API_TOKEN=your_gitlab_token_here
GITLAB_WEBHOOK_SECRET=your_webhook_secret_here
```

### 🐋 Docker Hub
```bash
DOCKER_USERNAME=your_dockerhub_username
DOCKER_PASSWORD=your_dockerhub_password
```

### 🐙 GitHub Integration
```bash
GITHUB_USERNAME=your_github_username
GITHUB_TOKEN=your_github_token_here
```

### 🗄️ Base de Données (AirQuality)
```bash
BDD_USER1_USERNAME=user1
BDD_USER1_PASSWORD=password1
BDD_USER2_USERNAME=user2
BDD_USER2_PASSWORD=password2
BDD_USER3_USERNAME=user3
BDD_USER3_PASSWORD=password3
BDD_USER4_USERNAME=user4
BDD_USER4_PASSWORD=password4
BDD_USER_ADMIN_USERNAME=admin
BDD_USER_ADMIN_PASSWORD=admin_password
```

### 🌐 DNS OVH
```bash
OVH_DNS_ZONE=your_dns_zone
OVH_DNS_SUBDOMAIN=your_subdomain
```

### 🔑 SSH Keys
```bash
# Clé SSH pour l'infrastructure Jenkins (existante)
airquality_server_key="-----BEGIN OPENSSH PRIVATE KEY-----
... contenu de la clé SSH pour Jenkins ...
-----END OPENSSH PRIVATE KEY-----"

# 🆕 NOUVELLE VARIABLE - Clé SSH pour le serveur de production AirQuality
AIRQUALITY_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
... contenu de la clé SSH du projet Qualité Air ...
-----END OPENSSH PRIVATE KEY-----"
```

## 🆕 Configuration Required pour AirQuality

### Dans le projet **hebergement_serveur**
Ajoutez dans votre fichier `.env` :

```bash
# Variable pour le credential SSH AirQuality
AIRQUALITY_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDvpyVg4wDrUF+PTetIk3b10EXWm2CtBFLw0VhpX/BS+QAAAJhuslVEbrJV
RAAAAAtzc2gtZWQyNTUxOQAAACDvpyVg4wDrUF+PTetIk3b10EXWm2CtBFLw0VhpX/BS+Q
AAAEB/9FXnWD7xJ6EkuiIMsi6vlps03QZftCJDZl5j4fqTY++nJWDjAOtQX49N60iTdvXQ
RdabYK0EUvDRWGlf8FL5AAAAEGdpdGxhYi1jaS1kZXBsb3kBAgMEBQ==
-----END OPENSSH PRIVATE KEY-----"
```

### Dans le projet **projet_qualite_air**
Votre fichier `.env` peut garder :

```bash
DEPLOY_USER=user
SSH_KEY_PATH=.ssh/key-gitlab-ci
key-gitlab-ci=xxxxx  # Peut être gardée pour compatibilité locale
```

## 🔄 Workflow de Configuration

### 1. Configuration Jenkins (Hébergement)
```bash
cd /c/programmation/Projets_python/hebergement_serveur
# Éditer le fichier .env pour ajouter AIRQUALITY_SSH_KEY
# Redémarrer Jenkins pour appliquer la nouvelle configuration CasC
```

### 2. Utilisation dans le Pipeline (AirQuality)
Le Jenkinsfile du projet AirQuality utilisera automatiquement le credential `ssh_key_production_server` qui sera créé par Jenkins CasC.

## 🧪 Test de Configuration

### Vérifier que Jenkins a bien chargé le credential :
1. Aller dans Jenkins > Manage Jenkins > Manage Credentials
2. Chercher le credential avec l'ID : `ssh_key_production_server`
3. Vérifier qu'il est de type "SSH Username with private key"
4. Username doit être : `user`

### Test de connectivité :
Le pipeline Jenkins testera automatiquement la connectivité SSH vers `192.168.1.134` avec ce credential.

## ⚠️ Sécurité

- **JAMAIS** commiter les fichiers `.env` contenant ces variables
- Les clés SSH doivent être au format OpenSSH (commencer par `-----BEGIN OPENSSH PRIVATE KEY-----`)
- Utilisez des tokens avec les permissions minimales nécessaires
- Rotez régulièrement les tokens et clés SSH

## 📁 Structure des Fichiers

```
hebergement_serveur/
├── .env                          # ← Variables d'environnement Jenkins (avec AIRQUALITY_SSH_KEY)
├── ci-cd/jenkins/casc/
│   ├── jenkins.yaml             # ← Configuration CasC (utilise les variables)
│   └── VARIABLES_ENV_JENKINS.md # ← Ce fichier

projet_qualite_air/
├── .env                         # ← Variables spécifiques au projet
├── .ssh/key-gitlab-ci          # ← Clé SSH locale
└── ci-cd/Jenkinsfile           # ← Pipeline (utilise ssh_key_production_server)
```

---

**Date de création** : 28/05/2025
**Dernière mise à jour** : 28/05/2025
**Auteur** : Configuration automatisée Jenkins CasC