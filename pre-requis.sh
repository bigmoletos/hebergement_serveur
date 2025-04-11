#!/bin/bash

# =====================================================
# Script d'installation des prérequis pour le serveur
# Ce script configure l'environnement de base nécessaire
# pour le déploiement de notre architecture microservices
# =====================================================

# Auteur: Franck DESMEDT
# Date: $(date +%Y-%m-%d)

# =====================================================
# Configuration des couleurs pour les messages
# Ces couleurs permettent de mieux distinguer les types
# de messages dans la console
# =====================================================
RED='\033[0;31m'    # Pour les messages d'erreur
GREEN='\033[0;32m'  # Pour les messages d'information
YELLOW='\033[1;33m' # Pour les messages d'avertissement
NC='\033[0m'        # Pour réinitialiser la couleur

# =====================================================
# Fonctions d'affichage des messages
# Ces fonctions standardisent l'affichage des messages
# avec des couleurs et des préfixes appropriés
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
# Le script doit être exécuté avec les droits root
# pour pouvoir installer les paquets et configurer
# le système
# =====================================================
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# =====================================================
# Chargement des variables d'environnement
# Ces variables sont définies dans le fichier .env
# et sont nécessaires pour la configuration
# =====================================================
if [ -f .env ]; then
    source .env
else
    log_error "Le fichier .env n'existe pas. Veuillez le créer avec les configurations nécessaires."
    exit 1
fi

# =====================================================
# Mise à jour du système
# Cette étape assure que tous les paquets sont à jour
# avant de procéder à l'installation
# =====================================================
log_message "Mise à jour du système..."
apt update && apt upgrade -y

# =====================================================
# Installation des paquets essentiels
# Ces paquets sont nécessaires pour :
# - sudo : gestion des privilèges
# - curl/wget : téléchargement de fichiers
# - git : gestion de version
# - vim/nano : éditeurs de texte
# - python3 : langage de programmation
# - net-tools : outils réseau
# - ufw : pare-feu
# - openssh-server : serveur SSH
# - fail2ban : protection contre les attaques
# - htop : monitoring système
# - dnsutils : outils DNS
# - docker.io : conteneurisation
# - docker-compose : orchestration de conteneurs
# =====================================================
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
    openssh-server \
    fail2ban \
    htop \
    dnsutils \
    docker.io \
    docker-compose

# =====================================================
# Configuration du pare-feu
# Cette configuration :
# - Bloque toutes les connexions entrantes par défaut
# - Autorise toutes les connexions sortantes
# - Ouvre les ports nécessaires (SSH, HTTP, HTTPS)
# =====================================================
log_message "Configuration du pare-feu..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# =====================================================
# Configuration de SSH
# Cette section :
# - Sauvegarde la configuration existante
# - Configure SSH pour une sécurité maximale
# - Désactive l'authentification par mot de passe
# - Limite les tentatives de connexion
# =====================================================
log_message "Configuration de SSH..."
mkdir -p /etc/ssh/backup
cp /etc/ssh/sshd_config /etc/ssh/backup/sshd_config.$(date +%Y%m%d)

# Configuration sécurisée de SSH
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
MaxSessions 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel INFO

# Restriction d'accès
AllowUsers ${SERVER_USER}
EOF

# =====================================================
# Configuration du répertoire SSH
# Cette section :
# - Crée le répertoire .ssh pour l'utilisateur
# - Configure les permissions appropriées
# - Prépare le fichier authorized_keys pour la clé
# =====================================================
log_message "Configuration du répertoire SSH pour l'utilisateur..."
mkdir -p /home/${SERVER_USER}/.ssh
chmod 700 /home/${SERVER_USER}/.ssh
touch /home/${SERVER_USER}/.ssh/authorized_keys
chmod 600 /home/${SERVER_USER}/.ssh/authorized_keys
chown -R ${SERVER_USER}:${SERVER_USER} /home/${SERVER_USER}/.ssh

# =====================================================
# Configuration de Fail2Ban
# Cette section :
# - Configure la protection contre les attaques par force brute
# - Définit les délais de bannissement
# - Active la protection pour SSH
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
# Création de la structure de répertoires
# Cette section crée l'arborescence nécessaire pour :
# - Les certificats SSL (ssl/)
# - Les clés SSH (ssh/)
# - Les logs des services (logs/)
# - Les configurations (config/)
# - Les services déployés (services/)
# - Les données persistantes (data/)
# =====================================================
log_message "Création des répertoires pour l'architecture microservices..."
mkdir -p /hebergement_serveur/{ssl,ssh,logs,config}
mkdir -p /hebergement_serveur/services/{jenkins,docker,api,monitoring}
mkdir -p /hebergement_serveur/data/{jenkins,docker,api,monitoring}

# =====================================================
# Configuration des permissions
# Cette section :
# - Définit les propriétaires des répertoires
# - Configure les permissions de sécurité
# - Crée les fichiers .gitkeep pour Git
# =====================================================
log_message "Configuration des permissions..."
chown -R ${SERVER_USER}:${SERVER_USER} /hebergement_serveur
chmod -R 755 /hebergement_serveur
chmod 700 /hebergement_serveur/ssh
chmod 600 /hebergement_serveur/ssl/* 2>/dev/null || true

# Création des fichiers .gitkeep pour maintenir la structure
touch /hebergement_serveur/ssl/.gitkeep
touch /hebergement_serveur/ssh/.gitkeep

# =====================================================
# Redémarrage des services
# Cette section :
# - Redémarre les services configurés
# - Active leur démarrage automatique
# =====================================================
log_message "Redémarrage des services..."
systemctl restart sshd
systemctl restart fail2ban
systemctl enable sshd
systemctl enable fail2ban

# =====================================================
# Message de fin et instructions
# Cette section :
# - Résume les étapes à suivre
# - Fournit les commandes nécessaires
# - Affiche la structure des répertoires
# =====================================================
log_message "Installation des prérequis terminée!"
log_warning "N'oubliez pas de :"
log_warning "1. Copier votre clé publique airquality_server_key dans /home/${SERVER_USER}/.ssh/authorized_keys"
log_warning "2. Tester la connexion SSH avec airquality_server_key"
log_warning "3. Vérifier que la connexion par mot de passe est bien désactivée"
log_warning "4. Configurer le fichier .env avec vos paramètres"

echo -e "\nPour copier votre clé publique :"
echo "scp ~/.ssh/airquality_server_key.pub ${SERVER_USER}@${IP_ADDRESS}:/home/${SERVER_USER}/.ssh/authorized_keys"

echo -e "\nPour tester la connexion :"
echo "ssh -i ~/.ssh/airquality_server_key ${SERVER_USER}@${IP_ADDRESS}"

echo -e "\nStructure des répertoires créée :"
echo "/hebergement_serveur/"
echo "├── ssl/                # Certificats SSL"
echo "├── ssh/               # Clés SSH"
echo "├── logs/              # Logs des services"
echo "├── config/            # Fichiers de configuration"
echo "├── services/          # Services déployés"
echo "│   ├── jenkins/       # Configuration Jenkins"
echo "│   ├── docker/        # Configuration Docker"
echo "│   ├── api/           # Configuration API"
echo "│   └── monitoring/    # Configuration monitoring"
echo "└── data/              # Données persistantes"
echo "    ├── jenkins/       # Données Jenkins"
echo "    ├── docker/        # Données Docker"
echo "    ├── api/           # Données API"
echo "    └── monitoring/    # Données monitoring"