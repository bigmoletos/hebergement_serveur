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
endpoint=ovh-eu

[ovh-eu]
application_key=6f1ea4004ed10b98
application_secret=321ed8151e9337d63d90d0e961a80dbb
consumer_key=0ca8c02e03f8a26b923b18b485eaf23f
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
    local domain=$1
    local subdomain=$2
    local record_type=$3

    # Récupération de l'ID de la zone
    zone_id=$(ovh --endpoint=ovh-eu dns-zone-list | grep $domain | awk '{print $1}')

    # Mise à jour de l'enregistrement
    ovh --endpoint=ovh-eu dns-zone-record-update $zone_id \
        --subDomain=$subdomain \
        --target=$CURRENT_IP \
        --ttl=60
}

# Mise à jour des domaines
update_dns_record "iaproject.fr" "airquality" "A"
update_dns_record "iaproject.fr" "www.airquality" "A"
update_dns_record "iaproject.fr" "jenkins.airquality" "A"
update_dns_record "iaproject.fr" "docker.airquality" "A"
update_dns_record "iaproject.fr" "api.airquality" "A"

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