#!/bin/bash

# =====================================================
# Script d'installation des prérequis pour le serveur
# Ce script configure l'environnement de base nécessaire
# pour le déploiement de notre architecture microservices
# conteneurisée avec Docker.
#
# Objectifs :
# 1. Mise à jour du système
# 2. Installation des outils essentiels
# 3. Installation et configuration de Docker
# 4. Configuration de la sécurité (pare-feu, SSH, Fail2Ban)
# 5. Création de la structure de dossiers pour les services
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-11
# Version: 1.0.0
#
# Historique des versions :
# 1.0.0 (2025-04-11) - Version initiale
#   - Mise en place de la structure de base
#   - Installation des prérequis essentiels
#   - Configuration de la sécurité
#   - Création de l'arborescence des dossiers
# =====================================================

# =====================================================
# Configuration des couleurs pour les messages
# Ces couleurs permettent de mieux distinguer les types
# de messages dans la console :
# - Vert : Informations
# - Rouge : Erreurs
# - Jaune : Avertissements
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# =====================================================
# Fonctions d'affichage des messages
# Ces fonctions standardisent l'affichage des messages
# avec des couleurs et des préfixes appropriés
# =====================================================
log_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

# =====================================================
# Vérification des privilèges root
# Le script doit être exécuté avec les droits root
# pour pouvoir installer les paquets et configurer
# le système
# =====================================================
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# =====================================================
# Chargement des variables d'environnement
# Ces variables sont définies dans le fichier .env
# et sont nécessaires pour la configuration.
# Si le fichier n'existe pas, on utilise des valeurs
# par défaut pour permettre l'installation initiale.
# =====================================================
load_env() {
    local env_file=".env"
    if [ -f "$env_file" ]; then
        log_message "Chargement du fichier $env_file..."
        # Lecture ligne par ligne du fichier .env
        while IFS= read -r line; do
            # Ignorer les lignes vides et les commentaires
            [[ -z "$line" || "$line" =~ ^# ]] && continue

            # Extraire la clé et la valeur (tout avant le premier #)
            key=$(echo "$line" | cut -d '=' -f 1 | tr -d ' ' | tr -d '"' | tr -d "'")

            # Pour les mots de passe, préserver les guillemets
            if [[ "$key" == *"PASSWORD"* || "$key" == *"SECRET"* ]]; then
                value=$(echo "$line" | cut -d '=' -f 2- | cut -d '#' -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
                value=$(echo "$line" | cut -d '=' -f 2- | cut -d '#' -f 1 | tr -d ' ' | tr -d '"' | tr -d "'")
            fi

            # Vérifier que la ligne contient bien une clé et une valeur
            if [[ -n "$key" && -n "$value" ]]; then
                # Exporter la variable
                export "$key=$value"
                log_message "Variable chargée : $key=$value"
            fi
        done < "$env_file"
    else
        log_warning "Le fichier $env_file n'existe pas. Utilisation des valeurs par défaut."
    fi
}

# Chargement des variables d'environnement
load_env

# Valeurs par défaut si non définies
if [ -z "$SERVER_USER" ]; then
    log_warning "SERVER_USER non défini dans .env, utilisation de l'utilisateur courant"
    SERVER_USER=$(whoami)
fi

# Vérification et nettoyage du nom d'utilisateur
SERVER_USER=$(echo "$SERVER_USER" | tr -d '#' | tr -d ' ' | tr -d '"' | tr -d "'" | tr -d '#' | tr -d ':' | tr -d ';' | tr -d '|' | tr -d '&' | tr -d '*' | tr -d '+' | tr -d '-' | tr -d '/' | tr -d '\\')
if [ -z "$SERVER_USER" ]; then
    log_error "Le nom d'utilisateur est vide après nettoyage"
    exit 1
fi

if ! id "$SERVER_USER" &>/dev/null; then
    log_error "L'utilisateur $SERVER_USER n'existe pas"
    exit 1
fi

# Affichage de l'utilisateur utilisé
log_message "Utilisation de l'utilisateur : $SERVER_USER"

# =====================================================
# Mise à jour du système
# Cette étape assure que tous les paquets sont à jour
# avant de procéder à l'installation
# =====================================================
log_message "Mise à jour du système..."

# Nettoyage des anciens dépôts avant la mise à jour
log_message "Nettoyage des anciens dépôts..."
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /etc/apt/sources.list.d/kubernetes.list
rm -f /usr/share/keyrings/jenkins-keyring.gpg
rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg

# Mise à jour du système
apt update && apt upgrade -y

# =====================================================
# Installation des paquets essentiels
# Ces paquets sont nécessaires pour :
# - curl/wget : téléchargement de fichiers
# - git : gestion de version
# - vim : éditeur de texte
# - htop : monitoring système
# - net-tools : outils réseau
# - ufw : pare-feu
# - fail2ban : protection contre les attaques
# - ca-certificates : certificats SSL
# - gnupg : gestion des clés GPG
# - lsb-release : informations sur la distribution
# =====================================================
log_message "Installation des paquets essentiels..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    ufw \
    fail2ban \
    ca-certificates \
    gnupg \
    lsb-release

# =====================================================
# Installation de Docker et Docker Compose
# Cette section :
# 1. Supprime les anciennes clés Docker si elles existent
# 2. Ajoute la clé GPG officielle de Docker
# 3. Configure le dépôt Docker
# 4. Installe Docker et Docker Compose
# =====================================================
log_message "Installation de Docker..."

# Nettoyage des anciens dépôts
log_message "Nettoyage des anciens dépôts..."
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /etc/apt/sources.list.d/kubernetes.list
rm -f /usr/share/keyrings/jenkins-keyring.gpg
rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg

# Suppression des anciennes clés Docker si elles existent
rm -f /usr/share/keyrings/docker-archive-keyring.gpg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mise à jour des dépôts et installation de Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# =====================================================
# Configuration du pare-feu
# Cette configuration :
# - Bloque toutes les connexions entrantes par défaut
# - Autorise toutes les connexions sortantes
# - Ouvre les ports nécessaires (SSH, HTTP, HTTPS)
# - Active le pare-feu
# =====================================================
log_message "Configuration du pare-feu..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# =====================================================
# Configuration de SSH
# Cette section :
# 1. Sauvegarde la configuration existante
# 2. Vérifie que la configuration est valide
# =====================================================
log_message "Configuration de SSH..."

# Sauvegarde de la configuration existante
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
    log_message "Configuration SSH sauvegardée"
else
    log_error "Le fichier de configuration SSH n'existe pas"
    exit 1
fi

# Vérification de la configuration SSH actuelle
log_message "Vérification de la configuration SSH actuelle..."
if ! sshd -t; then
    log_error "La configuration SSH actuelle est invalide"
    log_warning "Restauration de la configuration d'origine..."
    cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d) /etc/ssh/sshd_config
    exit 1
fi

# Vérification que l'utilisateur actuel a accès SSH
current_user=$(whoami)
if ! grep -q "AllowUsers.*$current_user" /etc/ssh/sshd_config; then
    log_warning "L'utilisateur $current_user n'est pas dans la liste AllowUsers"
    log_warning "Ajout de l'utilisateur à la configuration SSH..."
    if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        # Ajouter l'utilisateur à la liste existante
        sed -i "s/^AllowUsers.*/& $current_user/" /etc/ssh/sshd_config
    else
        # Créer une nouvelle ligne AllowUsers
        echo "AllowUsers $current_user" >> /etc/ssh/sshd_config
    fi

    # Vérification de la nouvelle configuration
    if ! sshd -t; then
        log_error "La nouvelle configuration SSH est invalide"
        log_warning "Restauration de la configuration d'origine..."
        cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d) /etc/ssh/sshd_config
        exit 1
    fi
fi

log_message "La configuration SSH est valide"

# =====================================================
# Création de la nouvelle structure de répertoires
# Cette structure est optimisée pour une architecture
# conteneurisée avec :
# - config/ : configurations des services
# - data/ : données persistantes des conteneurs
# - logs/ : logs centralisés
# - certs/ : certificats SSL (gérés par Traefik)
# - scripts/ : scripts de maintenance
# =====================================================
log_message "Création de la structure de répertoires..."
mkdir -p /hebergement_serveur/{config/{traefik,docker-compose,env},data/{portainer,api,monitoring},logs,certs,scripts}

# =====================================================
# Configuration des permissions
# Cette section :
# 1. Définit le propriétaire des répertoires
# 2. Configure les permissions de base
# 3. Restreint l'accès aux dossiers sensibles
# =====================================================
log_message "Configuration des permissions..."

# Vérification que l'utilisateur existe avant d'exécuter chown
if ! id "$SERVER_USER" &>/dev/null; then
    log_error "L'utilisateur $SERVER_USER n'existe pas, impossible de configurer les permissions"
    exit 1
fi

# Configuration des permissions avec vérification
if ! chown -R "${SERVER_USER}:${SERVER_USER}" /hebergement_serveur; then
    log_error "Échec de la configuration des permissions pour $SERVER_USER"
    exit 1
fi

chmod -R 755 /hebergement_serveur
chmod 700 /hebergement_serveur/config/env
chmod 700 /hebergement_serveur/certs

# =====================================================
# Configuration de Fail2Ban
# Cette section :
# 1. Configure la protection contre les attaques
# 2. Définit les délais de bannissement
# 3. Active la protection pour SSH
# =====================================================
log_message "Configuration de Fail2Ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF

# =====================================================
# Redémarrage des services
# Cette section :
# 1. Redémarre les services configurés
# 2. Active leur démarrage automatique
# =====================================================
log_message "Redémarrage des services..."

# Redémarrage de SSH avec vérification
if ! systemctl restart ssh; then
    log_error "Échec du redémarrage du service SSH. Vérification de la configuration..."
    systemctl status ssh
    exit 1
fi

systemctl restart fail2ban
systemctl enable fail2ban

# =====================================================
# Message de fin et instructions
# Cette section :
# 1. Affiche la structure des répertoires créée
# 2. Donne les prochaines étapes à suivre
# =====================================================
log_message "Installation des prérequis terminée!"
log_warning "Structure des répertoires créée :"
echo "/hebergement_serveur/"
echo "├── config/              # Configurations"
echo "│   ├── traefik/        # Configuration de Traefik"
echo "│   ├── docker-compose/ # Fichiers docker-compose"
echo "│   └── env/           # Variables d'environnement"
echo "├── data/               # Données persistantes"
echo "│   ├── portainer/"
echo "│   ├── api/"
echo "│   └── monitoring/"
echo "├── logs/               # Logs centralisés"
echo "├── certs/              # Certificats SSL"
echo "└── scripts/            # Scripts de maintenance"

log_warning "Prochaines étapes :"
log_warning "1. Vérifier la configuration SSH"
log_warning "2. Configurer Traefik comme reverse proxy"
log_warning "3. Déployer les services via Docker Compose"