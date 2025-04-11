#!/bin/bash

# Script d'installation pour serveur Ubuntu avec Docker, Jenkins, Kubernetes et gestion DNS dynamique
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

# Chargement des variables d'environnement
if [ -f .env ]; then
    source .env
else
    log_error "Le fichier .env n'existe pas. Veuillez le créer avec les configurations nécessaires."
    exit 1
fi

# Mise à jour du système
log_message "Mise à jour du système..."
apt update && apt upgrade -y

# Installation des paquets de base
log_message "Installation des paquets de base..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    dnsutils \
    fail2ban \
    ufw \
    python3 \
    python3-pip \
    python3-venv \
    certbot \
    python3-certbot-nginx

# Configuration du pare-feu
log_message "Configuration du pare-feu..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# Installation de Docker
log_message "Installation de Docker..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Installation de Docker Compose
log_message "Installation de Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Installation de Kubernetes
log_message "Installation de Kubernetes..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Installation de Jenkins
log_message "Installation de Jenkins..."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
echo "deb https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list
apt update
apt install -y jenkins

# Installation et configuration de ddclient pour DynDNS
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

# Configuration de Nginx comme Reverse Proxy
log_message "Configuration de Nginx comme Reverse Proxy..."

# Installation de Nginx
apt install -y nginx

# Création des répertoires pour les configurations
mkdir -p /etc/nginx/ssl
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Configuration de base de Nginx
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_disable "msie6";

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Configuration du site par défaut
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;

    location / {
        return 403;
    }
}
EOF

# Configuration pour Jenkins
cat > /etc/nginx/sites-available/jenkins.conf << EOF
server {
    listen 80;
    server_name jenkins.$DYNDNS_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name jenkins.$DYNDNS_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/jenkins.$DYNDNS_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jenkins.$DYNDNS_DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:$JENKINS_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Configuration pour Docker (Portainer)
cat > /etc/nginx/sites-available/docker.conf << EOF
server {
    listen 80;
    server_name docker.$DYNDNS_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name docker.$DYNDNS_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/docker.$DYNDNS_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/docker.$DYNDNS_DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:$DOCKER_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Activation des configurations
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/jenkins.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/docker.conf /etc/nginx/sites-enabled/

# Installation des certificats SSL
log_message "Installation des certificats SSL..."
certbot --nginx -d $DYNDNS_DOMAIN -d www.$DYNDNS_DOMAIN -d jenkins.$DYNDNS_DOMAIN -d docker.$DYNDNS_DOMAIN --non-interactive --agree-tos --email $NGINX_SSL_EMAIL

# Redémarrage des services
log_message "Redémarrage des services..."
systemctl restart docker
systemctl restart jenkins
systemctl restart ddclient
systemctl restart nginx
systemctl enable docker
systemctl enable jenkins
systemctl enable ddclient
systemctl enable nginx

# Création des répertoires pour les projets
log_message "Création des répertoires pour les projets..."
mkdir -p $DOCKER_DATA_DIR/{jenkins,nginx,apps}
chmod -R 755 $DOCKER_DATA_DIR

# Installation des outils de monitoring
log_message "Installation des outils de monitoring..."
apt install -y prometheus node-exporter

# Configuration finale
log_message "Configuration finale..."
usermod -aG docker jenkins
usermod -aG docker \$USER

# Message de fin
log_message "Installation terminée avec succès!"
log_warning "N'oubliez pas de :"
log_warning "1. Vérifier la configuration de Nginx : sudo nginx -t"
log_warning "2. Vérifier les certificats SSL : sudo certbot certificates"
log_warning "3. Configurer Jenkins selon vos besoins"
log_warning "4. Sécuriser vos conteneurs Docker"
log_warning "5. Configurer vos règles de pare-feu selon vos besoins"

echo "Pour accéder à Jenkins : https://jenkins.$DYNDNS_DOMAIN"
echo "Pour accéder à l'interface Docker : https://docker.$DYNDNS_DOMAIN"