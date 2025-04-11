#!/bin/bash

# Script de configuration des DNS OVH
# Auteur: Franck DESMEDT
# Date: $(date +%Y-%m-%d)

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fonction pour afficher les messages
log_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Installation des dépendances nécessaires
log_message "Installation des dépendances..."
apt update
apt install -y python3-pip
pip3 install ovh

# Création du répertoire de configuration
mkdir -p /etc/ovh
chmod 700 /etc/ovh

# Configuration des identifiants OVH
cat > /etc/ovh/ovh.conf << EOF
[default]
endpoint=https://eu.api.ovh.com/v1

[ovh-eu]
application_key=${OVH_APPLICATION_KEY}
application_secret=${OVH_APPLICATION_SECRET}
consumer_key=${OVH_CONSUMER_KEY}
EOF

# Création du script de mise à jour DNS
cat > /usr/local/bin/update_ovh_dns.sh << 'EOF'
#!/bin/bash

# Script de mise à jour des DNS OVH
# Nécessite le fichier de configuration /etc/ovh/ovh.conf

# Chargement des variables d'environnement
source /etc/ovh/ovh.conf

# Récupération de l'IP publique actuelle
CURRENT_IP=$(curl -s ifconfig.me)

# Fonction pour mettre à jour un enregistrement DNS
update_dns_record() {
    local zone=$1
    local subdomain=$2
    local record_id=$3

    # Mise à jour de l'enregistrement
    curl -X PUT "https://eu.api.ovh.com/v1/domain/zone/${zone}/record/${record_id}" \
        -H "Content-Type: application/json" \
        -H "X-Ovh-Application: ${OVH_APPLICATION_KEY}" \
        -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}" \
        -H "X-Ovh-Timestamp: $(date +%s)" \
        -d "{\"target\":\"${CURRENT_IP}\",\"ttl\":0}"
}

# Mise à jour des domaines avec les IDs
update_dns_record "${OVH_DNS_ZONE}" "${OVH_DNS_SUBDOMAIN}" "${OVH_DNS_RECORD_ID}"

# Log de la mise à jour
echo "$(date) - DNS mis à jour avec IP: $CURRENT_IP" >> /var/log/ovh_dns_update.log
EOF

# Rendre le script exécutable
chmod +x /usr/local/bin/update_ovh_dns.sh

# Ajout d'une tâche cron pour la mise à jour automatique
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/update_ovh_dns.sh") | crontab -

log_message "Configuration terminée avec succès!"
log_warning "N'oubliez pas de :"
log_warning "1. Configurer vos identifiants OVH dans /etc/ovh/ovh.conf"
log_warning "2. Modifier le script /usr/local/bin/update_ovh_dns.sh avec vos domaines"
log_warning "3. Tester la mise à jour des DNS avec la commande : /usr/local/bin/update_ovh_dns.sh"