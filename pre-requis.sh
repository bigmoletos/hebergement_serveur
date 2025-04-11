#!/bin/bash

# Script d'installation des prérequis
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

# Mise à jour du système
log_message "Mise à jour du système..."
apt update && apt upgrade -y

# Installation des paquets essentiels
log_message "Installation des paquets essentiels..."
apt install -y \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    python3 \
    python3-pip \
    net-tools \
    ufw \
    openssh-server

# Configuration du pare-feu de base
log_message "Configuration du pare-feu..."
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# Création du répertoire de travail
log_message "Vérification du répertoire de travail..."
# Récupération de l'utilisateur qui a lancé le script avec sudo
REAL_USER=$(logname || who am i | awk '{print $1}')
if [ -z "$REAL_USER" ]; then
    log_error "Impossible de déterminer l'utilisateur réel"
    exit 1
fi

if [ -d "/hebergement_serveur" ]; then
    log_warning "Le répertoire /hebergement_serveur existe déjà"
    log_message "Configuration des permissions..."
    chown -R $REAL_USER:$REAL_USER /hebergement_serveur
    chmod 755 /hebergement_serveur
else
    log_message "Création du répertoire de travail..."
    mkdir -p /hebergement_serveur
    chown -R $REAL_USER:$REAL_USER /hebergement_serveur
    chmod 755 /hebergement_serveur
fi

# Vérification de Python et pip
log_message "Vérification de Python..."
python3 --version
pip3 --version

# Message de fin
log_message "Installation des prérequis terminée!"
log_warning "N'oubliez pas de :"
log_warning "1. Copier les fichiers nécessaires dans /hebergement_serveur/"
log_warning "2. Configurer le fichier .env"
log_warning "3. Donner les bonnes permissions aux fichiers"

echo -e "\nMéthode 1 - Avec MobaXterm :"
echo "1. Ouvrez MobaXterm"
echo "2. Dans le panneau de gauche, naviguez jusqu'au dossier contenant vos fichiers"
echo "3. Faites glisser les fichiers suivants vers le dossier /hebergement_serveur/ du serveur :"
echo "   - .env"
echo "   - install_server.sh"
echo "   - configure_ovh_dns.sh"

echo -e "\nMéthode 2 - Avec SCP (si vous n'êtes pas déjà connecté au serveur) :"
echo "scp .env install_server.sh configure_ovh_dns.sh user@192.168.1.134:/hebergement_serveur/"

echo -e "\nAprès la copie, configurez les permissions :"
echo "chmod +x /hebergement_serveur/*.sh"
echo "chmod 600 /hebergement_serveur/.env"