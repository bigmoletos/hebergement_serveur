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
# Fonction pour charger les variables d'environnement
# =====================================================
load_env() {
    # Se déplacer dans le répertoire du script
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"

    log_message "Chargement des variables d'environnement..."
    log_message "Répertoire du script : $SCRIPT_DIR"
    log_message "Répertoire courant : $(pwd)"
    log_message "Contenu du répertoire :"
    ls -la

    if [ -f .env ]; then
        log_message "Fichier .env trouvé, début du chargement..."
        log_message "Contenu du fichier .env :"
        cat .env
        log_message "Début du traitement ligne par ligne..."

        while IFS= read -r line; do
            # Ignorer les lignes vides et les commentaires
            if [[ -z "$line" ]]; then
                log_warning "Ligne vide ignorée"
                continue
            fi
            if [[ "$line" =~ ^[[:space:]]*# ]]; then
                log_warning "Commentaire ignoré : $line"
                continue
            fi

            # Extraire la clé et la valeur
            if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"

                # Nettoyer la valeur (supprimer les commentaires et les espaces)
                value=$(echo "$value" | sed 's/#.*$//' | xargs)

                # Exporter la variable
                export "$key=$value"
                log_message "Variable chargée : $key=$value"
            else
                log_warning "Ligne ignorée (format invalide) : $line"
            fi
        done < .env

        log_message "Fin du chargement des variables"
    else
        log_warning "Fichier .env non trouvé, utilisation des valeurs par défaut"
    fi

    # Vérification des variables obligatoires
    REQUIRED_VARS=("DYNDNS_DOMAIN" "OVH_APPLICATION_SECRET" "NGINX_SSL_EMAIL")
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Variable obligatoire non définie : $var"
            exit 1
        fi
    done

    log_message "Variables d'environnement chargées :"
    env | grep -E '^DYNDNS_|^OVH_|^NGINX_'
}

# =====================================================
# Chargement des variables d'environnement
# =====================================================
load_env

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
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
protocol=dyndns2
server=ovh.com
login=${DYNDNS_USERNAME}
password='${DYNDNS_PASSWORD}'
zone=${DYNDNS_DOMAIN}
${DYNDNS_DOMAIN}
EOF

# Redémarrer ddclient
systemctl restart ddclient
systemctl enable ddclient

# Vérification de la configuration DNS
log_message "Vérification de la configuration DNS..."
IP_PUBLIC=$(curl -s ifconfig.me)
log_message "IP publique actuelle : ${IP_PUBLIC}"

# Vérification des enregistrements DNS
for domain in ${DYNDNS_DOMAIN} traefik.${DYNDNS_DOMAIN} portainer.${DYNDNS_DOMAIN}; do
    log_message "Vérification de ${domain}..."
    dig +short ${domain} || log_error "Impossible de résoudre ${domain}"
done

# Vérification du service ddclient
log_message "Vérification du service ddclient..."
systemctl status ddclient

# Test de mise à jour DNS
log_message "Test de mise à jour DNS..."
ddclient -daemon=0 -debug -verbose -noquiet

# Vérification des logs
log_message "Vérification des logs ddclient..."
journalctl -u ddclient -n 50

# =====================================================
# Configuration de Traefik comme Reverse Proxy
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
      email: $NGINX_SSL_EMAIL
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
      rule: "Host(\`traefik.$DYNDNS_DOMAIN\`)"
      service: api@internal
      tls:
        certResolver: letsencrypt
      middlewares:
        - auth

    portainer:
      rule: "Host(\`portainer.$DYNDNS_DOMAIN\`)"
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
          - "admin:\`openssl passwd -apr1 \$TRAEFIK_PASSWORD\`"
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

# Vérification des conteneurs
log_message "Vérification des conteneurs..."
docker ps

# Vérification des logs
log_message "Vérification des logs de Traefik..."
docker logs traefik

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

# =====================================================
# Fonction pour tester la connexion à l'API OVH
# =====================================================
test_ovh_api() {
    log_message "Test de connexion à l'API OVH..."

    # Vérification des variables d'API
    if [ -z "$OVH_APPLICATION_KEY" ] || [ -z "$OVH_APPLICATION_SECRET" ] || [ -z "$OVH_CONSUMER_KEY" ]; then
        log_error "Variables d'API OVH manquantes"
        return 1
    fi

    # Test de connexion à l'API
    response=$(curl -s -X GET \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Timestamp: $(date +%s)" \
        -H "X-Ovh-Signature: $(echo -n "$OVH_APPLICATION_SECRET+$OVH_CONSUMER_KEY+GET+/domain/zone/$DYNDNS_DOMAIN/record+$(date +%s)" | sha1sum | cut -d' ' -f1)" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
        "https://api.ovh.com/1.0/domain/zone/$DYNDNS_DOMAIN/record")

    if [ $? -eq 0 ]; then
        log_message "Connexion à l'API OVH réussie"
        log_message "Réponse de l'API : $response"
        return 0
    else
        log_error "Échec de la connexion à l'API OVH"
        return 1
    fi
}

# =====================================================
# Test de l'API OVH
# =====================================================
test_ovh_api