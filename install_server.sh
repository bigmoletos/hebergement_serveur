#!/bin/bash

# =====================================================
# Script d'installation du serveur
# Ce script configure l'environnement de production
# pour le déploiement de notre architecture microservices
# conteneurisée avec Docker et Traefik.
#
# Objectifs :
# 1. Installation des outils de monitoring
# 2. Configuration de Traefik comme reverse proxy
# 3. Configuration de la gestion DNS dynamique
# 4. Installation des certificats SSL
# 5. Déploiement des services conteneurisés
# =====================================================

# Auteur: Franck DESMEDT
# Date: $(date +%Y-%m-%d)
# Version: 1.0.0
#
# Historique des versions :
# 1.0.0 (2025-04-11) - Version initiale
#   - Configuration de l'environnement de production
#   - Installation des outils de monitoring
#   - Configuration de Traefik
#   - Gestion des certificats SSL
# =====================================================

# =====================================================
# Configuration des couleurs pour les messages
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# =====================================================
# Fonctions d'affichage des messages
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
# =====================================================
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# =====================================================
# Chargement des variables d'environnement
# =====================================================
log_message "Chargement des variables d'environnement..."

# Source du script load_env.sh
source /hebergement_serveur/scripts/load_env.sh

# Vérification des variables obligatoires
REQUIRED_VARS=("DYNDNS_DOMAIN" "NGINX_SSL_EMAIL" "TRAEFIK_PASSWORD" "PORTAINER_ADMIN_PASSWORD")
for var in "${REQUIRED_VARS[@]}"; do
    value=$(load_env "$var" "debug")
    if [ $? -ne 0 ]; then
        log_error "Variable obligatoire non définie : $var"
        exit 1
    else
        log_message "Variable $var est définie"
    fi
done

# =====================================================
# Installation des prérequis
# =====================================================
log_message "Installation des prérequis..."

# Mise à jour du système
apt-get update && apt-get upgrade -y

# Installation des paquets nécessaires
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    certbot \
    python3-certbot-nginx

# =====================================================
# Installation de Docker
# =====================================================
log_message "Installation de Docker..."

# Ajout de la clé GPG officielle de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajout du dépôt Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation de Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# =====================================================
# Installation de Docker Compose
# =====================================================
log_message "Installation de Docker Compose..."

# Téléchargement de Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Rendre Docker Compose exécutable
chmod +x /usr/local/bin/docker-compose

# =====================================================
# Configuration de l'environnement Python
# =====================================================
log_message "Configuration de l'environnement Python..."

# Création de l'environnement virtuel
python3 -m venv /hebergement_serveur/venv

# Activation de l'environnement virtuel
source /hebergement_serveur/venv/bin/activate

# Installation des dépendances Python
pip install -r /hebergement_serveur/requirements.txt

# =====================================================
# Configuration de Nginx
# =====================================================
log_message "Configuration de Nginx..."

# Création des répertoires pour Nginx
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Configuration de base de Nginx
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# =====================================================
# Configuration des certificats SSL
# =====================================================
log_message "Configuration des certificats SSL..."

# Création des répertoires pour les certificats
mkdir -p /etc/letsencrypt/live/$(load_env "DYNDNS_DOMAIN" "debug")

# =====================================================
# Configuration de Traefik
# =====================================================
log_message "Configuration de Traefik..."

# Création des répertoires pour Traefik
mkdir -p /hebergement_serveur/config/traefik
mkdir -p /hebergement_serveur/certs

# =====================================================
# Configuration de Portainer
# =====================================================
log_message "Configuration de Portainer..."

# Création des répertoires pour Portainer
mkdir -p /hebergement_serveur/data/portainer

# =====================================================
# Configuration des services
# =====================================================
log_message "Configuration des services..."

# Redémarrage des services
systemctl restart nginx
systemctl restart docker

# =====================================================
# Message de fin
# =====================================================
log_message "Installation du serveur terminée avec succès!"
log_message "Prochaines étapes :"
log_message "1. Exécuter configure_ovh_dns.sh pour configurer le DNS"
log_message "2. Exécuter configure_traefik.sh pour configurer Traefik"
log_message "3. Configurer vos applications dans Portainer"
log_message "4. Vérifier les certificats SSL"
log_message "5. Configurer vos règles de pare-feu selon vos besoins"