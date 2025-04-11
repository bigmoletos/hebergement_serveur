# Guide d'Installation et Configuration du Serveur

## 1. Prérequis

### 1.1 Installation des prérequis

1. Sur le serveur, créez le dossier d'installation :
```bash
sudo mkdir -p /hebergement_serveur
sudo chown ${SERVER_USER}:${SERVER_USER} /hebergement_serveur
sudo chmod 755 /hebergement_serveur
```

2. Depuis votre machine locale (dans un nouveau terminal PowerShell), copiez le script `pre-requis.sh` :
```bash
scp pre-requis.sh ${SERVER_USER}@${IP_ADDRESS}:/hebergement_serveur/pre-requis.sh
```

3. Sur le serveur, exécutez le script des prérequis :
```bash
sudo chmod +x /hebergement_serveur/pre-requis.sh
sudo /hebergement_serveur/pre-requis.sh
```

4. Vérifiez que tous les paquets sont installés :
```bash
python3 --version
pip3 --version
ufw status
```

### 1.2 Copie des fichiers nécessaires

1. Depuis votre machine locale, copiez les fichiers de configuration :
```bash
scp .env install_server.sh configure_ovh_dns.sh ${SERVER_USER}@${IP_ADDRESS}:/hebergement_serveur/
```

2. Sur le serveur, configurez les permissions :
```bash
chmod +x /hebergement_serveur/*.sh
chmod 600 /hebergement_serveur/.env
```

### 1.3 Configuration de l'authentification SSH

1. Sur votre machine locale, générez une nouvelle paire de clés SSH :
```bash
cd hebergement_serveur/ssh
ssh-keygen -t rsa -b 4096 -C "serveur_airquality" -f airquality_server_key
```

2. Copiez la clé publique sur le serveur :
```bash
type airquality_server_key.pub | ssh ${SERVER_USER}@${IP_ADDRESS} "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

3. Testez la connexion avec la nouvelle clé :
```bash
ssh -i airquality_server_key ${SERVER_USER}@${IP_ADDRESS}
```

4. Pour une utilisation plus simple, ajoutez la clé à votre agent SSH :
```bash
ssh-add airquality_server_key
```

5. Optionnel : Créez un fichier `config` dans `~/.ssh/` pour simplifier la connexion :
```bash
Host airquality
    HostName ${IP_ADDRESS}
    User ${SERVER_USER}
    IdentityFile ~/.ssh/airquality_server_key
```

6. Désactivez l'authentification par mot de passe sur le serveur (optionnel mais recommandé) :
```bash
sudo nano /etc/ssh/sshd_config
```
Modifiez les lignes suivantes :
```conf
PasswordAuthentication no
PermitRootLogin no
```
Puis redémarrez le service SSH :
```bash
sudo systemctl restart sshd
```

### 1.4 Sécurité des clés

1. Les clés SSH et SSL sont des fichiers sensibles qui ne doivent JAMAIS être versionnés dans Git :
   - Les clés privées (`*.key`, `*_key`)
   - Les certificats (`*.pem`, `*.crt`)
   - Les demandes de signature (`*.csr`)

2. Pour exclure ces fichiers de Git, créez un fichier `.gitignore` à la racine du projet :
```bash
# Clés SSH
/ssh/
/ssh/*
!/ssh/.gitkeep

# Certificats SSL
/ssl/
/ssl/*
!/ssl/.gitkeep

# Fichiers sensibles
.env
*.log
*.swp
*.swo
*~
```

3. Vérifiez que les fichiers sensibles ne sont pas suivis par Git :
```bash
git status
```

4. Si des fichiers sensibles sont déjà suivis, supprimez-les de l'index Git :
```bash
git rm --cached ssh/*_key
git rm --cached ssl/*.key
git rm --cached ssl/*.csr
```

5. Assurez-vous que les permissions des fichiers sont correctes :
```bash
chmod 600 ssh/*_key
chmod 600 ssl/*.key
chmod 600 ssl/*.csr
```

6. Stockez les clés de manière sécurisée :
   - Utilisez un gestionnaire de mots de passe pour les clés
   - Faites des sauvegardes sécurisées des clés
   - Ne partagez jamais les clés privées

## 2. Connexion au serveur

### 2.1 Sur Windows (PowerShell)

1. Ouvrez un terminal PowerShell et naviguez vers le dossier contenant la clé :
```bash
cd C:\programmation\Projets_python\hebergement_serveur\ssh
```

2. Connectez-vous au serveur avec la clé :
```bash
ssh -i .\airquality_server_key user@192.168.1.134
```

### 2.2 Sur Linux/Mac

```bash
ssh -i airquality_server_key ${SERVER_USER}@${IP_ADDRESS}
```

### 2.3 Configuration simplifiée (optionnel)

Pour simplifier la connexion, vous pouvez créer un fichier `config` dans `~/.ssh/` :

```bash
Host airquality
    HostName ${IP_ADDRESS}
    User ${SERVER_USER}
    IdentityFile ~/.ssh/airquality_server_key
```

Puis vous pourrez vous connecter simplement avec :
```bash
ssh airquality
```

## 3. Configuration de l'API OVH

### 3.1 Création des identifiants API OVH

1. Connectez-vous à votre compte OVH (https://www.ovh.com/auth/)
2. Cliquez sur votre nom en haut à droite
3. Sélectionnez "Produits et services"
4. Dans le menu de gauche, cliquez sur "API"
5. Cliquez sur "Créer une clé API"
6. Remplissez les informations :
   - Nom : "Serveur DynDNS"
   - Description : "Gestion des DNS dynamiques pour le serveur"
   - Validity : "Unlimited"
   - Rights :
     - Sélectionnez "GET, POST, PUT, DELETE" pour "Domaines"
     - Sélectionnez "GET, POST, PUT, DELETE" pour "DNS"

7. Notez les identifiants générés :
   - Application Key (AK) : C'est l'identifiant de votre application
   - Application Secret (AS) : C'est le secret de votre application
   - Consumer Key (CK) : C'est la clé d'authentification pour les appels API

### 3.2 Configuration du fichier .env

Ajoutez les informations suivantes dans votre fichier `.env` :

```env
# Configuration OVH
OVH_APPLICATION_KEY=${OVH_APPLICATION_KEY}        # AK généré dans l'API OVH
OVH_APPLICATION_SECRET=${OVH_APPLICATION_SECRET}  # AS généré dans l'API OVH
OVH_CONSUMER_KEY=${OVH_CONSUMER_KEY}              # CK généré dans l'API OVH

# Configuration DynDNS
DYNDNS_DOMAIN=${DYNDNS_DOMAIN}                    # Votre domaine chez OVH
DYNDNS_SUBDOMAINS=${DYNDNS_SUBDOMAINS}            # Sous-domaines à gérer
DYNDNS_UPDATE_INTERVAL=${DYNDNS_UPDATE_INTERVAL}  # Intervalle de mise à jour en secondes
DYNDNS_PASSWORD=${DYNDNS_PASSWORD}                # Mot de passe DynDNS OVH

# Configuration Nginx
NGINX_SSL_EMAIL=${NGINX_SSL_EMAIL}                # Email pour les certificats SSL
NGINX_DOMAINS=${NGINX_DOMAINS}                    # Liste des domaines à sécuriser

# Configuration Jenkins
JENKINS_ADMIN_USER=${JENKINS_ADMIN_USER}          # Utilisateur admin Jenkins
JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD}  # Mot de passe admin Jenkins

# Configuration Docker
DOCKER_NETWORK_NAME=${DOCKER_NETWORK_NAME}        # Nom du réseau Docker
DOCKER_DATA_DIR=${DOCKER_DATA_DIR}                # Répertoire des données Docker
```

## 4. Configuration du DynDNS

### 4.1 Installation et configuration de ddclient

1. Si ddclient est déjà installé, supprimez-le proprement :
```bash
sudo apt-get remove --purge ddclient
sudo apt-get autoremove
```

2. Installez ddclient :
```bash
sudo apt-get install ddclient
```

3. Lors de l'installation, vous aurez plusieurs écrans de configuration :

   Premier écran :
   - Service DNS dynamique : sélectionnez `Autre`

   Deuxième écran :
   - Protocole de mise à jour : entrez `dyndns2`

   Troisième écran :
   - Serveur DNS dynamique : entrez `www.ovh.com`

   Quatrième écran :
   - Identifiant : entrez la valeur de DYNDNS_DOMAIN

   Cinquième écran :
   - Mot de passe : entrez la valeur de DYNDNS_PASSWORD

   Sixième écran :
   - Méthode de découverte d'adresse IP : sélectionnez `Service de découverte d'IP basée sur le web`

   Septième écran :
   - Interface réseau : laissez vide (appuyez sur Entrée)

   Huitième écran :
   - Hôtes à mettre à jour : entrez les domaines complets

4. Vérification de la configuration :

   a. Testez la configuration en mode debug :
   ```bash
   sudo ddclient -daemon=0 -debug -verbose -noquiet
   ```

   b. Vérifiez le statut du service :
   ```bash
   sudo systemctl status ddclient
   ```

   c. Consultez les logs pour voir les mises à jour :
   ```bash
   sudo tail -f /var/log/syslog | grep ddclient
   ```

   d. Vérifiez que vos domaines sont bien mis à jour :
   ```bash
   dig +short airquality.iaproject.fr
   dig +short www.airquality.iaproject.fr
   dig +short jenkins.airquality.iaproject.fr
   dig +short docker.airquality.iaproject.fr
   dig +short api.airquality.iaproject.fr
   ```

5. Une fois l'installation terminée, modifiez le fichier `/etc/ddclient.conf` :
```bash
sudo nano /etc/ddclient.conf
```

6. Remplacez tout le contenu par :
```conf
# Configuration pour OVH DynDNS
daemon=${DYNDNS_UPDATE_INTERVAL}
syslog=yes
pid=/var/run/ddclient.pid
ssl=yes
use=web, web=https://api.ipify.org/

# Configuration OVH pour airquality.iaproject.fr
protocol=dyndns2
server=www.ovh.com
login=${DYNDNS_USERNAME}
password=${DYNDNS_PASSWORD}
airquality.iaproject.fr

# Configuration OVH pour www.airquality.iaproject.fr
protocol=dyndns2
server=www.ovh.com
login=${DYNDNS_USERNAME}
password=${DYNDNS_PASSWORD}
www.airquality.iaproject.fr

# Configuration OVH pour jenkins.airquality.iaproject.fr
protocol=dyndns2
server=www.ovh.com
login=${DYNDNS_USERNAME}
password=${DYNDNS_PASSWORD}
jenkins.airquality.iaproject.fr

# Configuration OVH pour docker.airquality.iaproject.fr
protocol=dyndns2
server=www.ovh.com
login=${DYNDNS_USERNAME}
password=${DYNDNS_PASSWORD}
docker.airquality.iaproject.fr

# Configuration OVH pour api.airquality.iaproject.fr
protocol=dyndns2
server=www.ovh.com
login=${DYNDNS_USERNAME}
password=${DYNDNS_PASSWORD}
api.airquality.iaproject.fr
```

Après avoir modifié le fichier, redémarrez le service :
```bash
sudo systemctl restart ddclient
```

Pour vérifier à nouveau :
```bash
sudo ddclient -daemon=0 -debug -verbose -noquiet
```

## 5. Configuration du Reverse Proxy Traefik

### 5.1 Installation de Traefik

1. Créez le répertoire de configuration :
```bash
sudo mkdir -p /opt/traefik
sudo chown -R $USER:$USER /opt/traefik
```

2. Créez le fichier de configuration `traefik.yml` :
```yaml
# Configuration globale
global:
  checkNewVersion: true
  sendAnonymousUsage: false

# Configuration des entrées
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

# Configuration des certificats
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${NGINX_SSL_EMAIL}
      storage: /opt/traefik/acme.json
      httpChallenge:
        entryPoint: web

# Configuration des providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/opt/traefik/conf"
    watch: true

# Configuration du dashboard
api:
  dashboard: true
  insecure: true

# Configuration des logs
log:
  level: INFO
  format: common
```

3. Créez le fichier de configuration pour les routes `conf/routes.yml` :
```yaml
http:
  routers:
    # Route pour Jenkins
    jenkins:
      rule: "Host(`jenkins.${DYNDNS_DOMAIN}`)"
      service: jenkins
      tls:
        certResolver: letsencrypt

    # Route pour Docker
    docker:
      rule: "Host(`docker.${DYNDNS_DOMAIN}`)"
      service: docker
      tls:
        certResolver: letsencrypt

    # Route pour l'API
    api:
      rule: "Host(`api.${DYNDNS_DOMAIN}`)"
      service: api
      tls:
        certResolver: letsencrypt

  services:
    jenkins:
      loadBalancer:
        servers:
          - url: "http://jenkins:${JENKINS_PORT}"

    docker:
      loadBalancer:
        servers:
          - url: "http://portainer:${DOCKER_PORT}"

    api:
      loadBalancer:
        servers:
          - url: "http://api:3000"
```

4. Créez le fichier `docker-compose.yml` :
```yaml
version: '3'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./conf:/opt/traefik/conf:ro
      - ./acme.json:/opt/traefik/acme.json
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${DYNDNS_DOMAIN}`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"

networks:
  traefik-public:
    name: traefik-public
```

5. Créez le fichier acme.json avec les bonnes permissions :
```bash
touch acme.json
chmod 600 acme.json
```

6. Démarrez Traefik :
```bash
docker-compose up -d
```

### 5.2 Configuration des services

1. Pour Jenkins, ajoutez ces labels dans son docker-compose.yml :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.jenkins.rule=Host(`jenkins.${DYNDNS_DOMAIN}`)"
  - "traefik.http.routers.jenkins.tls.certresolver=letsencrypt"
```

2. Pour Portainer (Docker), ajoutez ces labels :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.docker.rule=Host(`docker.${DYNDNS_DOMAIN}`)"
  - "traefik.http.routers.docker.tls.certresolver=letsencrypt"
```

3. Pour votre API, ajoutez ces labels :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.rule=Host(`api.${DYNDNS_DOMAIN}`)"
  - "traefik.http.routers.api.tls.certresolver=letsencrypt"
```

### 5.3 Vérification

1. Vérifiez que Traefik est en cours d'exécution :
```bash
docker ps | grep traefik
```

2. Vérifiez les logs :
```bash
docker logs traefik
```

3. Accédez au dashboard :
```
https://traefik.${DYNDNS_DOMAIN}
```

4. Vérifiez que les certificats sont bien générés :
```bash
ls -l /opt/traefik/acme.json
```

## 6. Maintenance

### 6.1 Mise à jour automatique des certificats

Traefik gère automatiquement le renouvellement des certificats Let's Encrypt. Aucune configuration supplémentaire n'est nécessaire.

### 6.2 Surveillance des logs

```bash
# Logs Traefik
docker logs -f traefik

# Logs des services
docker-compose logs -f
```

## 7. Dépannage

### 7.1 Problèmes de certificats

1. Vérifiez les logs de Traefik :
```bash
docker logs traefik
```

2. Vérifiez le fichier acme.json :
```bash
cat /opt/traefik/acme.json
```

### 7.2 Problèmes de routage

1. Vérifiez la configuration des routes :
```bash
cat /opt/traefik/conf/routes.yml
```

2. Vérifiez les labels des conteneurs :
```bash
docker inspect <nom_du_conteneur>
```

### 7.3 Problèmes de connexion

1. Vérifiez que les ports sont bien exposés :
```bash
netstat -tulpn | grep LISTEN
```

2. Vérifiez les règles du pare-feu :
```bash
sudo ufw status
```