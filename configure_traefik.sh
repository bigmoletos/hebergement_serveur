#!/bin/bash

# =====================================================
# Script de configuration de Traefik
# Ce script configure Traefik comme reverse proxy
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-12
# Version: 1.0.0

# =====================================================
# Chargement des fonctions de logging
# =====================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/scripts/logger.sh"

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
# Fonction de masquage des informations sensibles
# =====================================================
mask_sensitive() {
    local value="$1"
    local visible_chars=5
    if [ -z "$value" ]; then
        echo "***"
    else
        echo "${value:0:$visible_chars}***"
    fi
}

# =====================================================
# Vérification des privilèges root
# =====================================================
check_root

# =====================================================
# Chargement des variables d'environnement
# =====================================================
log_message "Chargement des variables d'environnement..."

# Liste des variables requises
required_vars=(
    "DYNDNS_DOMAIN"
    "NGINX_SSL_EMAIL"
    "TRAEFIK_PASSWORD"
)

# Vérification et exportation de chaque variable
for var in "${required_vars[@]}"; do
    value=$(load_env "$var" "debug")
    if [ $? -ne 0 ]; then
        log_error "Variable requise non définie : $var"
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
# Installation des dépendances
# =====================================================
log_message "Installation des dépendances..."
execute_command "apt-get update" "Mise à jour des paquets"
execute_command "apt-get install -y docker.io docker-compose" "Installation des dépendances"

# =====================================================
# Configuration de Traefik
# =====================================================
log_message "Configuration de Traefik..."

# Création des répertoires nécessaires
create_directory "/etc/traefik"
create_directory "/etc/traefik/ssl"

# Création du fichier de configuration Traefik
cat > /etc/traefik/traefik.yml << EOF
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

certificatesResolvers:
  myresolver:
    acme:
      email: ${NGINX_SSL_EMAIL}
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web

accessLog:
  filePath: "/var/log/traefik/access.log"
  format: json

log:
  filePath: "/var/log/traefik/traefik.log"
  level: INFO
EOF

# Création du fichier docker-compose.yml
cat > /etc/traefik/docker-compose.yml << EOF
version: '3'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    ports:
      - 80:80
      - 443:443
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/traefik/traefik.yml:/traefik.yml:ro
      - /etc/traefik/acme.json:/acme.json
      - /etc/traefik/ssl:/etc/traefik/ssl
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.${DYNDNS_DOMAIN}\`)"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=myresolver"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=traefik-auth"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:${TRAEFIK_PASSWORD}"

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/traefik/portainer:/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.rule=Host(\`portainer.${DYNDNS_DOMAIN}\`)"
      - "traefik.http.routers.portainer.tls=true"
      - "traefik.http.routers.portainer.tls.certresolver=myresolver"
      - "traefik.http.routers.portainer.service=portainer"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
      - "traefik.http.routers.portainer.middlewares=portainer-auth"
      - "traefik.http.middlewares.portainer-auth.basicauth.users=admin:${TRAEFIK_PASSWORD}"

networks:
  proxy:
    external: true
EOF

# Création du fichier acme.json
touch /etc/traefik/acme.json
chmod 600 /etc/traefik/acme.json

# Création du réseau Docker
execute_command "docker network create proxy" "Création du réseau Docker"

# =====================================================
# Démarrage des services
# =====================================================
log_message "Démarrage des services..."

# Arrêt des conteneurs existants
execute_command "docker-compose -f /etc/traefik/docker-compose.yml down" "Arrêt des conteneurs existants"

# Démarrage des conteneurs
execute_command "docker-compose -f /etc/traefik/docker-compose.yml up -d" "Démarrage des conteneurs"

# =====================================================
# Vérification de l'état des services
# =====================================================
log_message "Vérification de l'état des services..."

# Attente de 10 secondes pour laisser le temps aux services de démarrer
sleep 10

# Vérification des conteneurs
check_service_status "Traefik" "traefik"
check_service_status "Portainer" "portainer"

# =====================================================
# Affichage des informations de connexion
# =====================================================
log_message "Configuration terminée avec succès"
log_message "Traefik Dashboard: https://traefik.${DYNDNS_DOMAIN}"
log_message "Portainer: https://portainer.${DYNDNS_DOMAIN}"
log_message "Utilisateur: admin"
log_message "Mot de passe: $(mask_sensitive "${TRAEFIK_PASSWORD}")"