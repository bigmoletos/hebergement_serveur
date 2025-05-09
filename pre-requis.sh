#!/bin/bash

# =====================================================
# Script d'installation des prérequis pour le serveur
# Ce script configure l'environnement de base nécessaire
# pour le déploiement de notre architecture microservices
# conteneurisée avec Docker.
#
# Objectifs :
# 1. Mise à jour du système
# 2. Installation des outils essentiels
# 3. Installation et configuration de Docker
# 4. Configuration de la sécurité (pare-feu, SSH, Fail2Ban)
# 5. Création de la structure de dossiers pour les services
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-11
# Version: 1.0.0
#
# Historique des versions :
# 1.0.0 (2025-04-11) - Version initiale
#   - Mise en place de la structure de base
#   - Installation des prérequis essentiels
#   - Configuration de la sécurité
#   - Création de l'arborescence des dossiers
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

# Définir l'utilisateur par défaut
SERVER_USER="user"

# Vérification si SERVER_USER est défini dans .env
if [ -z "$SERVER_USER" ]; then
    log_warning "SERVER_USER non défini dans .env, utilisation de l'utilisateur par défaut"
    SERVER_USER="user"
fi

log_message "Utilisation de l'utilisateur : $SERVER_USER"

# =====================================================
# Mise à jour du système
# =====================================================
log_message "Mise à jour du système..."

# Nettoyage des anciens dépôts avant la mise à jour
log_message "Nettoyage des anciens dépôts..."
execute_command "rm -f /etc/apt/sources.list.d/jenkins.list" "Suppression du dépôt Jenkins"
execute_command "rm -f /etc/apt/sources.list.d/kubernetes.list" "Suppression du dépôt Kubernetes"
execute_command "rm -f /usr/share/keyrings/jenkins-keyring.gpg" "Suppression de la clé Jenkins"
execute_command "rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg" "Suppression de la clé Kubernetes"

# Mise à jour du système
execute_command "apt update && apt upgrade -y" "Mise à jour du système"

# =====================================================
# Installation des paquets essentiels
# =====================================================
log_message "Installation des paquets essentiels..."
execute_command "apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    ufw \
    fail2ban \
    ca-certificates \
    gnupg \
    lsb-release \
    netcat-openbsd" "Installation des paquets essentiels"

# =====================================================
# Installation de Docker et Docker Compose
# =====================================================
log_message "Installation de Docker..."

# Nettoyage des anciens dépôts
log_message "Nettoyage des anciens dépôts..."
execute_command "rm -f /etc/apt/sources.list.d/jenkins.list" "Suppression du dépôt Jenkins"
execute_command "rm -f /etc/apt/sources.list.d/kubernetes.list" "Suppression du dépôt Kubernetes"
execute_command "rm -f /usr/share/keyrings/jenkins-keyring.gpg" "Suppression de la clé Jenkins"
execute_command "rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg" "Suppression de la clé Kubernetes"

# Suppression des anciennes clés Docker si elles existent
execute_command "rm -f /usr/share/keyrings/docker-archive-keyring.gpg" "Suppression de l'ancienne clé Docker"

# Ajout de la clé GPG officielle de Docker
execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "Ajout de la clé GPG Docker"

# Configuration du dépôt Docker
execute_command "echo \
  \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null" "Configuration du dépôt Docker"

# Installation de Docker
execute_command "apt update" "Mise à jour des dépôts"
execute_command "apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Installation de Docker"

# =====================================================
# Configuration du pare-feu
# =====================================================
log_message "Configuration du pare-feu..."
execute_command "ufw default deny incoming" "Configuration du pare-feu : refus des connexions entrantes par défaut"
execute_command "ufw default allow outgoing" "Configuration du pare-feu : autorisation des connexions sortantes"
execute_command "ufw allow ssh" "Configuration du pare-feu : autorisation du port SSH"
execute_command "ufw allow http" "Configuration du pare-feu : autorisation du port HTTP"
execute_command "ufw allow https" "Configuration du pare-feu : autorisation du port HTTPS"
execute_command "ufw --force enable" "Activation du pare-feu"

# =====================================================
# Configuration de SSH
# =====================================================
log_message "Configuration de SSH..."

# Sauvegarde de la configuration existante
if [ -f /etc/ssh/sshd_config ]; then
    execute_command "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.\$(date +%Y%m%d)" "Sauvegarde de la configuration SSH"
else
    log_error "Le fichier de configuration SSH n'existe pas"
    exit 1
fi

# Configuration minimale et sécurisée de SSH
cat > /etc/ssh/sshd_config << EOF
# Configuration de base
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentification
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Sécurité
X11Forwarding no
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 600
ClientAliveCountMax 3

# Logs
SyslogFacility AUTH
LogLevel INFO

# Utilisateurs autorisés
AllowUsers $SERVER_USER

# Configuration pour SCP/SFTP
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Vérification de la configuration
if ! sshd -t; then
    log_error "La configuration SSH est invalide"
    log_warning "Restauration de la configuration d'origine..."
    execute_command "cp /etc/ssh/sshd_config.backup.\$(date +%Y%m%d) /etc/ssh/sshd_config" "Restauration de la configuration SSH"
    exit 1
fi

log_message "La configuration SSH est valide"

# Redémarrage de SSH avec vérification
execute_command "systemctl restart ssh" "Redémarrage du service SSH"

# =====================================================
# Création de la nouvelle structure de répertoires
# =====================================================
log_message "Création de la structure de répertoires..."
create_directory "/hebergement_serveur/config/traefik"
create_directory "/hebergement_serveur/config/docker-compose"
create_directory "/hebergement_serveur/config/env"
create_directory "/hebergement_serveur/data/portainer"
create_directory "/hebergement_serveur/data/api"
create_directory "/hebergement_serveur/data/monitoring"
create_directory "/hebergement_serveur/logs"
create_directory "/hebergement_serveur/certs"
create_directory "/hebergement_serveur/scripts"

# =====================================================
# Configuration des permissions
# =====================================================
log_message "Configuration des permissions..."

# Vérification que l'utilisateur existe avant d'exécuter chown
if ! id "$SERVER_USER" &>/dev/null; then
    log_error "L'utilisateur $SERVER_USER n'existe pas, impossible de configurer les permissions"
    exit 1
fi

# Configuration des permissions avec vérification
execute_command "chown -R \"${SERVER_USER}:${SERVER_USER}\" /hebergement_serveur" "Configuration du propriétaire des répertoires"
execute_command "chmod -R 755 /hebergement_serveur" "Configuration des permissions de base"
execute_command "chmod 700 /hebergement_serveur/config/env" "Restriction de l'accès au dossier env"
execute_command "chmod 700 /hebergement_serveur/certs" "Restriction de l'accès au dossier certs"

# =====================================================
# Configuration de Fail2Ban
# =====================================================
log_message "Configuration de Fail2Ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF

# =====================================================
# Redémarrage des services
# =====================================================
log_message "Redémarrage des services..."
execute_command "systemctl restart fail2ban" "Redémarrage de Fail2Ban"
execute_command "systemctl enable fail2ban" "Activation du démarrage automatique de Fail2Ban"

# =====================================================
# Message de fin et instructions
# =====================================================
log_message "Installation des prérequis terminée!"
log_warning "Structure des répertoires créée :"
echo "/hebergement_serveur/"
echo "├── config/              # Configurations"
echo "│   ├── traefik/        # Configuration de Traefik"
echo "│   ├── docker-compose/ # Fichiers docker-compose"
echo "│   └── env/           # Variables d'environnement"
echo "├── data/               # Données persistantes"
echo "│   ├── portainer/"
echo "│   ├── api/"
echo "│   └── monitoring/"
echo "├── logs/               # Logs centralisés"
echo "├── certs/              # Certificats SSL"
echo "└── scripts/            # Scripts de maintenance"

log_warning "Prochaines étapes :"
log_warning "1. Vérifier la configuration SSH"
log_warning "2. Configurer Traefik comme reverse proxy"
log_warning "3. Déployer les services via Docker Compose"