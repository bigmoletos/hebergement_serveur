#!/bin/bash

# =====================================================
# Script de configuration DNS OVH
# Ce script configure la gestion DNS via l'API OVH
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
# Installation des dépendances
# =====================================================
log_message "Installation des dépendances..."

# Vérification des paquets déjà installés
check_package() {
    local package=$1
    if dpkg -l | grep -q "^ii  $package "; then
        log_message "$package est déjà installé"
        return 0
    else
        return 1
    fi
}

# Vérification de Python3
if check_package "python3"; then
    log_message "Python3 est déjà installé"
else
    execute_command "apt-get install -y python3" "Installation de Python3"
fi

# Vérification de pip3
if command -v pip3 &> /dev/null; then
    log_message "pip3 est déjà installé"
else
    execute_command "apt-get install -y python3-pip" "Installation de pip3"
fi

# Vérification de ca-certificates
if check_package "ca-certificates"; then
    log_message "ca-certificates est déjà installé"
else
    execute_command "apt-get install -y ca-certificates" "Installation des certificats système"
fi

# Vérification finale
if ! command -v python3 &> /dev/null; then
    log_error "Python3 n'est pas installé"
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    log_error "pip3 n'est pas installé"
    exit 1
fi

log_message "Python $(python3 --version) et pip $(pip3 --version) sont prêts"

# =====================================================
# Chargement des variables d'environnement
# =====================================================
log_message "Chargement des variables d'environnement..."

# Liste des variables OVH requises
ovh_vars=(
    "OVH_APPLICATION_KEY"
    "OVH_APPLICATION_SECRET"
    "OVH_CONSUMER_KEY"
    "OVH_DNS_ZONE"
    "OVH_DNS_SUBDOMAIN"
    "OVH_DNS_RECORD_ID"
    "IP_FREEBOX"
)

# Chargement et exportation de chaque variable
for var in "${ovh_vars[@]}"; do
    value=$(source "$SCRIPT_DIR/scripts/load_env.sh" "$var")
    if [ $? -ne 0 ]; then
        log_error "Variable non définie : $var"
        exit 1
    else
        # Exportation de la variable
        export "$var=$value"
        # Masquage des valeurs sensibles dans les logs
        if [[ "$var" == *"KEY"* ]] || [[ "$var" == *"SECRET"* ]]; then
            log_message "Variable définie et exportée : $var=$(mask_sensitive "$value")"
        else
            log_message "Variable définie et exportée : $var=$value"
        fi
    fi
done

# =====================================================
# Vérification de la configuration via config.py
# =====================================================
log_message "Vérification de la configuration..."

# Exécution du script Python pour vérifier la configuration
python3 - << EOF
import sys
import os

# Ajout du répertoire scripts au PYTHONPATH
script_dir = os.path.dirname(os.path.abspath(__file__))
scripts_dir = os.path.join(script_dir, 'scripts')
sys.path.append(scripts_dir)

from config import config
from logger import setup_logger

logger = setup_logger('ovh_dns')

# Liste des variables requises
required_vars = [
    'OVH_APPLICATION_KEY',
    'OVH_APPLICATION_SECRET',
    'OVH_CONSUMER_KEY',
    'OVH_DNS_ZONE',
    'OVH_DNS_SUBDOMAIN',
    'OVH_DNS_RECORD_ID',
    'IP_FREEBOX'
]

# Vérification des variables
if not config.check_required_vars(required_vars):
    logger.error("Configuration incomplète")
    sys.exit(1)

logger.info("Configuration vérifiée avec succès")
EOF

if [ $? -ne 0 ]; then
    log_error "Erreur lors de la vérification de la configuration"
    exit 1
fi

# =====================================================
# Installation du module logger
# =====================================================
log_message "Installation du module logger..."
execute_command "mkdir -p /usr/local/lib/python3.10/dist-packages" "Création du répertoire pour les modules Python"
execute_command "cp $SCRIPT_DIR/scripts/logger.py /usr/local/lib/python3.10/dist-packages/" "Copie du module logger"

# =====================================================
# Configuration de l'API OVH
# =====================================================
log_message "Configuration de l'API OVH..."

# Création du répertoire de configuration
create_directory "/etc/ovh"

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
create_directory "/usr/local/bin"

# Création du script Python
cat > /usr/local/bin/update_dns.py << EOF
#!/usr/bin/env python3

import ovh
import socket
import os
import sys

from logger import setup_logger, mask_sensitive, check_required_vars, log_exception

# Configuration du logger
logger = setup_logger('ovh_dns', '/var/log/ovh_dns.log')

def get_public_ip():
    try:
        # Utilisation de l'IP_FREEBOX définie dans les variables d'environnement
        ip_freebox = os.getenv('IP_FREEBOX')
        if not ip_freebox:
            logger.error("Variable IP_FREEBOX non définie")
            return None
        return ip_freebox
    except Exception as e:
        log_exception(logger, e, "Erreur lors de la récupération de l'IP publique")
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
            'OVH_DNS_RECORD_ID',
            'IP_FREEBOX'
        ]

        if not check_required_vars(required_vars, logger):
            return False

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

        logger.info(f"Nouvelle IP publique: {mask_sensitive(new_ip)}")

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

        logger.info(f"Enregistrement DNS mis à jour: {mask_sensitive(str(result))}")
        return True

    except Exception as e:
        log_exception(logger, e, "Erreur lors de la mise à jour DNS")
        return False

if __name__ == "__main__":
    logger.info("Début de la mise à jour DNS")
    if update_dns_record():
        logger.info("Mise à jour DNS réussie")
    else:
        logger.error("Échec de la mise à jour DNS")
EOF

# Rendre le script exécutable
execute_command "chmod +x /usr/local/bin/update_dns.py" "Rendre le script exécutable"

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
execute_command "/usr/local/bin/update_dns.py" "Mise à jour DNS initiale"

log_message "Configuration DNS OVH terminée avec succès"