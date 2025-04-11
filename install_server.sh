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
# Date: 2025-04-11
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
source /hebergement_serveur/scripts/load_env.sh

# =====================================================
# Installation des outils de monitoring
# =====================================================
log_message "Installation des outils de monitoring..."
apt install -y prometheus node-exporter

# =====================================================
# Installation et configuration de ddclient pour DynDNS
# =====================================================
log_message "Installation de ddclient pour DynDNS..."
apt install -y ddclient

# Configuration de ddclient pour OVH
cat > /etc/ddclient.conf << EOF
# Configuration pour OVH
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
ssl=yes
use=web, web=checkip.dyndns.org/, web-skip='IP Address'
protocol=dyndns2
server=www.ovh.com
login=$DYNDNS_DOMAIN
password=$OVH_APPLICATION_SECRET
$DYNDNS_DOMAIN
EOF

# =====================================================
# Configuration de Traefik comme Reverse Proxy
# =====================================================
log_message "Configuration de Traefik..."

# Création des répertoires pour Traefik
mkdir -p /hebergement_serveur/config/traefik
mkdir -p /hebergement_serveur/certs

# Configuration de base de Traefik
cat > /hebergement_serveur/config/traefik/traefik.yml << EOF
# Configuration globale
global:
  checkNewVersion: true
  sendAnonymousUsage: false

# Configuration de l'API et du Dashboard
api:
  dashboard: true
  insecure: true

# Configuration des entrées
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

# Configuration des certificats
certificatesResolvers:
  myresolver:
    acme:
      email: $NGINX_SSL_EMAIL
      storage: /hebergement_serveur/certs/acme.json
      httpChallenge:
        entryPoint: web

# Configuration des providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: /hebergement_serveur/config/traefik
    watch: true
EOF

# Configuration des middlewares
cat > /hebergement_serveur/config/traefik/middlewares.yml << EOF
http:
  middlewares:
    secure-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        frameDeny: true
        sslRedirect: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
EOF

# Création du fichier acme.json
touch /hebergement_serveur/certs/acme.json
chmod 600 /hebergement_serveur/certs/acme.json

# =====================================================
# Déploiement des services via Docker Compose
# =====================================================
log_message "Déploiement des services..."

# Création du fichier docker-compose.yml principal
cat > /hebergement_serveur/config/docker-compose/docker-compose.yml << EOF
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /hebergement_serveur/config/traefik:/etc/traefik
      - /hebergement_serveur/certs:/certs
    networks:
      - traefik_public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.$DYNDNS_DOMAIN\`)"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=myresolver"
      - "traefik.http.routers.traefik.middlewares=secure-headers@file"

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /hebergement_serveur/data/portainer:/data
    networks:
      - traefik_public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.rule=Host(\`portainer.$DYNDNS_DOMAIN\`)"
      - "traefik.http.routers.portainer.tls=true"
      - "traefik.http.routers.portainer.tls.certresolver=myresolver"
      - "traefik.http.routers.portainer.middlewares=secure-headers@file"

networks:
  traefik_public:
    name: traefik_public
EOF

# =====================================================
# Redémarrage des services
# =====================================================
log_message "Redémarrage des services..."
systemctl restart docker
systemctl restart ddclient

# Démarrage des conteneurs
cd /hebergement_serveur/config/docker-compose
docker compose up -d

# =====================================================
# Message de fin et instructions
# =====================================================
log_message "Installation terminée avec succès!"
log_warning "N'oubliez pas de :"
log_warning "1. Vérifier les certificats SSL : docker logs traefik"
log_warning "2. Configurer Portainer selon vos besoins"
log_warning "3. Sécuriser vos conteneurs Docker"
log_warning "4. Configurer vos règles de pare-feu selon vos besoins"

echo "Pour accéder à Traefik : https://traefik.$DYNDNS_DOMAIN"
echo "Pour accéder à Portainer : https://portainer.$DYNDNS_DOMAIN"