#!/bin/bash

# =====================================================
# Script de configuration DNS OVH
# Ce script configure la gestion DNS via l'API OVH
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-12
# Version: 1.0.0

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

# Liste des variables OVH requises
ovh_vars=(
    "OVH_APPLICATION_KEY"
    "OVH_APPLICATION_SECRET"
    "OVH_CONSUMER_KEY"
    "OVH_DNS_ZONE"
    "OVH_DNS_SUBDOMAIN"
    "OVH_DNS_RECORD_ID"
)

# Vérification et exportation de chaque variable
for var in "${ovh_vars[@]}"; do
    value=$(load_env "$var" "debug")
    if [ $? -ne 0 ]; then
        log_error "Variable OVH non définie : $var"
        exit 1
    else
        # Exportation de la variable
        export "$var=$value"
        log_message "Variable OVH définie et exportée : $var=${value:0:4}..."  # Afficher seulement les 4 premiers caractères pour la sécurité
    fi
done

# =====================================================
# Installation des dépendances
# =====================================================
log_message "Installation des dépendances..."
apt-get update
apt-get install -y python3 python3-pip python3-ovh

# =====================================================
# Configuration de l'API OVH
# =====================================================
log_message "Configuration de l'API OVH..."

# Création du répertoire de configuration
mkdir -p /etc/ovh

# Création du fichier de configuration
cat > /etc/ovh/ovh.conf << EOF
[default]
endpoint=ovh-eu
application_key=${OVH_APPLICATION_KEY}
application_secret=${OVH_APPLICATION_SECRET}
consumer_key=${OVH_CONSUMER_KEY}
EOF

# =====================================================
# Création du script de mise à jour DNS
# =====================================================
log_message "Création du script de mise à jour DNS..."

# Création du répertoire pour les scripts
mkdir -p /usr/local/bin

# Création du script Python
cat > /usr/local/bin/update_dns.py << EOF
#!/usr/bin/env python3

import ovh
import socket
import logging
import os
import sys
import traceback

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/ovh_dns.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def get_public_ip():
    try:
        # Utilisation de api.ipify.org pour obtenir l'IP publique
        import requests
        response = requests.get('https://api.ipify.org')
        return response.text
    except Exception as e:
        logger.error(f"Erreur lors de la récupération de l'IP publique: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        return None

def update_dns_record():
    try:
        # Vérification des variables d'environnement
        required_vars = [
            'OVH_APPLICATION_KEY',
            'OVH_APPLICATION_SECRET',
            'OVH_CONSUMER_KEY',
            'OVH_DNS_ZONE',
            'OVH_DNS_SUBDOMAIN',
            'OVH_DNS_RECORD_ID'
        ]

        for var in required_vars:
            if var not in os.environ:
                logger.error(f"Variable d'environnement manquante : {var}")
                return False
            else:
                logger.info(f"Variable {var} trouvée")

        # Configuration du client OVH avec les variables d'environnement
        logger.info("Configuration du client OVH...")
        client = ovh.Client(
            endpoint='ovh-eu',
            application_key=os.environ['OVH_APPLICATION_KEY'],
            application_secret=os.environ['OVH_APPLICATION_SECRET'],
            consumer_key=os.environ['OVH_CONSUMER_KEY']
        )
        logger.info("Client OVH configuré avec succès")

        # Récupération de l'IP publique
        logger.info("Récupération de l'IP publique...")
        new_ip = get_public_ip()
        if not new_ip:
            logger.error("Impossible de récupérer l'IP publique")
            return False

        logger.info(f"Nouvelle IP publique: {new_ip}")

        # Mise à jour de l'enregistrement DNS
        logger.info("Mise à jour de l'enregistrement DNS...")
        logger.info(f"Zone DNS: {os.environ['OVH_DNS_ZONE']}")
        logger.info(f"Sous-domaine: {os.environ['OVH_DNS_SUBDOMAIN']}")
        logger.info(f"ID d'enregistrement: {os.environ['OVH_DNS_RECORD_ID']}")

        result = client.put(
            f'/domain/zone/{os.environ["OVH_DNS_ZONE"]}/record/{os.environ["OVH_DNS_RECORD_ID"]}',
            subDomain=os.environ['OVH_DNS_SUBDOMAIN'],
            target=new_ip,
            ttl=60
        )

        logger.info(f"Enregistrement DNS mis à jour: {result}")
        return True

    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour DNS: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        return False

if __name__ == "__main__":
    logger.info("Début de la mise à jour DNS")
    if update_dns_record():
        logger.info("Mise à jour DNS réussie")
    else:
        logger.error("Échec de la mise à jour DNS")
EOF

# Installation de python-dotenv
pip3 install python-dotenv

# Rendre le script exécutable
chmod +x /usr/local/bin/update_dns.py

# =====================================================
# Configuration du cron pour la mise à jour automatique
# =====================================================
log_message "Configuration du cron pour la mise à jour automatique..."

# Ajout de la tâche cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/update_dns.py") | crontab -

# =====================================================
# Exécution initiale du script
# =====================================================
log_message "Exécution initiale du script de mise à jour DNS..."
/usr/local/bin/update_dns.py

log_message "Configuration DNS OVH terminée avec succès"