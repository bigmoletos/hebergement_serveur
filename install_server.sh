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
# Chargement des fonctions de logging
# =====================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/scripts/logger.sh"

# =====================================================
# Vérification des privilèges root
# =====================================================
check_root

# =====================================================
# Chargement des variables d'environnement
# =====================================================
log_message "Chargement des variables d'environnement..."

# Source du script load_env.sh
source "$SCRIPT_DIR/scripts/load_env.sh"

# Vérification des variables obligatoires
REQUIRED_VARS=("DYNDNS_DOMAIN" "NGINX_SSL_EMAIL" "TRAEFIK_PASSWORD" "PORTAINER_ADMIN_PASSWORD")
for var in "${REQUIRED_VARS[@]}"; do
    value=$(load_env "$var" "debug")
    if [ $? -ne 0 ]; then
        log_error "Variable obligatoire non définie : $var"
        exit 1
    else
        # Exportation de la variable
        export "$var=$value"
        # Masquage des valeurs sensibles dans les logs
        if [[ "$var" == *"PASSWORD"* ]]; then
            log_message "Variable définie et exportée : $var=$(mask_sensitive "$value")"
        else
            log_message "Variable définie et exportée : $var=$value"
        fi
    fi
done

# =====================================================
# Installation des prérequis
# =====================================================
log_message "Installation des prérequis..."

# Mise à jour du système
execute_command "apt-get update && apt-get upgrade -y" "Mise à jour du système"

# Installation des paquets nécessaires
execute_command "apt-get install -y \
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
    python3-certbot-nginx" "Installation des paquets nécessaires"

# =====================================================
# Installation de Docker
# =====================================================
log_message "Installation de Docker..."

# Ajout de la clé GPG officielle de Docker
execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "Ajout de la clé GPG Docker"

# Ajout du dépôt Docker
execute_command "echo \
  \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null" "Configuration du dépôt Docker"

# Installation de Docker
execute_command "apt-get update" "Mise à jour des dépôts"
execute_command "apt-get install -y docker-ce docker-ce-cli containerd.io" "Installation de Docker"

# =====================================================
# Installation de Docker Compose
# =====================================================
log_message "Installation de Docker Compose..."

# Téléchargement de Docker Compose
execute_command "curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose" "Téléchargement de Docker Compose"

# Rendre Docker Compose exécutable
execute_command "chmod +x /usr/local/bin/docker-compose" "Configuration des permissions de Docker Compose"

# =====================================================
# Configuration de l'environnement Python
# =====================================================
log_message "Configuration de l'environnement Python..."

# Création de l'environnement virtuel
execute_command "python3 -m venv /hebergement_serveur/venv" "Création de l'environnement virtuel"

# Activation de l'environnement virtuel
source /hebergement_serveur/venv/bin/activate

# Installation des dépendances Python
execute_command "pip install -r /hebergement_serveur/requirements.txt" "Installation des dépendances Python"

# =====================================================
# Configuration de Nginx
# =====================================================
log_message "Configuration de Nginx..."

# Création des répertoires pour Nginx
create_directory "/etc/nginx/sites-available"
create_directory "/etc/nginx/sites-enabled"

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
create_directory "/etc/letsencrypt/live/$(load_env "DYNDNS_DOMAIN" "debug")"

# =====================================================
# Configuration de Traefik
# =====================================================
log_message "Configuration de Traefik..."

# Création des répertoires pour Traefik
create_directory "/hebergement_serveur/config/traefik"
create_directory "/hebergement_serveur/certs"

# =====================================================
# Configuration de Portainer
# =====================================================
log_message "Configuration de Portainer..."

# Création des répertoires pour Portainer
create_directory "/hebergement_serveur/data/portainer"

# =====================================================
# Configuration des services
# =====================================================
log_message "Configuration des services..."

# Redémarrage des services
execute_command "systemctl restart nginx" "Redémarrage de Nginx"
execute_command "systemctl restart docker" "Redémarrage de Docker"

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