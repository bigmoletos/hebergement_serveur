#!/bin/bash

# Script de configuration de Traefik
# Auteur: Franck DESMEDT
# Date: $(date +%Y-%m-%d)

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
REQUIRED_VARS=("DYNDNS_DOMAIN" "NGINX_SSL_EMAIL" "TRAEFIK_PASSWORD")
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
# Configuration de Traefik
# =====================================================
log_message "Configuration de Traefik..."

# Création des répertoires pour Traefik
mkdir -p /hebergement_serveur/config/traefik
mkdir -p /hebergement_serveur/certs

# Configuration de base de Traefik
cat > /hebergement_serveur/config/traefik/traefik.yml << EOF
global:
  checkNewVersion: false
  sendAnonymousUsage: false

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
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: $(load_env "NGINX_SSL_EMAIL" "debug")
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web

api:
  dashboard: true
  insecure: false

accessLog: {}
EOF

# Configuration dynamique de Traefik
mkdir -p /hebergement_serveur/config/traefik/dynamic
cat > /hebergement_serveur/config/traefik/dynamic/config.yml << EOF
http:
  routers:
    traefik-dashboard:
      rule: "Host(\`traefik.$(load_env "DYNDNS_DOMAIN" "debug")\`)"
      service: api@internal
      tls:
        certResolver: letsencrypt
      middlewares:
        - auth

    portainer:
      rule: "Host(\`portainer.$(load_env "DYNDNS_DOMAIN" "debug")\`)"
      service: portainer
      tls:
        certResolver: letsencrypt
      middlewares:
        - auth

  services:
    portainer:
      loadBalancer:
        servers:
          - url: "http://portainer:9000"

  middlewares:
    auth:
      basicAuth:
        users:
          - "admin:\`openssl passwd -apr1 \$(load_env "TRAEFIK_PASSWORD" "debug")\`"
EOF

# Création du fichier acme.json
touch /hebergement_serveur/certs/acme.json
chmod 600 /hebergement_serveur/certs/acme.json

# =====================================================
# Configuration Docker Compose pour Traefik
# =====================================================
log_message "Configuration Docker Compose pour Traefik..."

mkdir -p /hebergement_serveur/config/docker-compose
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
      - "traefik.http.routers.traefik.rule=Host(\`traefik.$(load_env "DYNDNS_DOMAIN" "debug")\`)"
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
      - "traefik.http.routers.portainer.rule=Host(\`portainer.$(load_env "DYNDNS_DOMAIN" "debug")\`)"
      - "traefik.http.routers.portainer.tls=true"
      - "traefik.http.routers.portainer.tls.certresolver=myresolver"
      - "traefik.http.routers.portainer.middlewares=secure-headers@file"

networks:
  traefik_public:
    name: traefik_public
EOF

# =====================================================
# Démarrage des services
# =====================================================
log_message "Démarrage des services..."

# Redémarrage de Docker
systemctl restart docker

# Démarrage des conteneurs
cd /hebergement_serveur/config/docker-compose
docker compose up -d

# Vérification des conteneurs
log_message "Vérification des conteneurs..."
docker ps

# Vérification des logs
log_message "Vérification des logs de Traefik..."
docker logs traefik

# =====================================================
# Message de fin
# =====================================================
log_message "Configuration de Traefik terminée avec succès!"
log_message "URLs d'accès aux services :"
log_message "1. Interface Traefik : https://traefik.$(load_env "DYNDNS_DOMAIN" "debug")"
log_message "   - Identifiants : admin / $(load_env "TRAEFIK_PASSWORD" "debug")"
log_message "2. Interface Portainer : https://portainer.$(load_env "DYNDNS_DOMAIN" "debug")"
log_message "   - Identifiants : admin / $(load_env "PORTAINER_ADMIN_PASSWORD" "debug")"

log_warning "N'oubliez pas de :"
log_warning "1. Vérifier les certificats SSL : docker logs traefik"
log_warning "2. Configurer Portainer selon vos besoins"
log_warning "3. Sécuriser vos conteneurs Docker"
log_warning "4. Configurer vos règles de pare-feu selon vos besoins"