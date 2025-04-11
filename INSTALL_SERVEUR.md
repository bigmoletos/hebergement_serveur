# Guide d'Installation et Configuration du Serveur

## 1. Prérequis

### 1.1 Installation des prérequis

1. Sur le serveur, créez le dossier d'installation :
```bash
sudo mkdir -p /hebergement_serveur
sudo chown ${SERVER_USER}:${SERVER_USER} /hebergement_serveur
sudo chmod 755 /hebergement_serveur
```

2. Depuis votre machine locale (dans un nouveau terminal PowerShell), copiez les fichiers nécessaires :
```bash

# Copie des fichiers de configuration vers le serveur
scp -i "ssh/airquality_server_key" .env INSTALL_SERVEUR.md install_server.sh pre-requis.sh configure_ovh_dns.sh .ovhconfig user@192.168.1.134:/hebergement_serveur/
```

3. Sur le serveur, donnez les permissions d'exécution et lancez le script des prérequis :
```bash
cd /hebergement_serveur
sudo chmod +x *.sh
sudo ./pre-requis.sh
```

Le script va :
- Mettre à jour le système
- Installer Docker et Docker Compose
- Configurer le pare-feu
- Sécuriser SSH
- Créer la structure de répertoires suivante :
  ```
  /hebergement_serveur/
  ├── config/              # Configurations
  │   ├── traefik/        # Configuration de Traefik
  │   ├── docker-compose/ # Fichiers docker-compose
  │   └── env/           # Variables d'environnement
  ├── data/               # Données persistantes
  │   ├── jenkins/
  │   ├── portainer/
  │   ├── api/
  │   └── monitoring/
  ├── logs/               # Logs centralisés
  ├── certs/              # Certificats SSL
  └── scripts/            # Scripts de maintenance
  ```

4. Vérifiez l'installation :
```bash
# Vérifier Docker
docker --version
docker-compose --version

# Vérifier le pare-feu
sudo ufw status

# Vérifier SSH
sudo systemctl status sshd
```

### 1.2 Configuration de l'authentification SSH

La clé SSH doit être dans le répertoire standard `~/.ssh/` de l'utilisateur :
```bash
# Sur le serveur
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Depuis votre machine locale, copiez la clé publique :
```bash
type airquality_server_key.pub | ssh ${SERVER_USER}@${IP_ADDRESS} "cat >> ~/.ssh/authorized_keys"
chmod 600 ~/.ssh/authorized_keys
```

### 1.3 Configuration de Traefik

1. Créez les fichiers de configuration dans `/hebergement_serveur/config/traefik/` :
```bash
cd /hebergement_serveur/config/traefik
```

2. Créez le fichier `docker-compose.yml` :
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
      - ./config:/etc/traefik/config:ro
      - ./acme.json:/acme.json
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${DYNDNS_DOMAIN}`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"

networks:
  traefik-public:
    external: true
```

3. Créez le réseau Docker :
```bash
docker network create traefik-public
```

4. Démarrez Traefik :
```bash
docker-compose up -d
```

### 1.4 Déploiement des services

Chaque service (Jenkins, Portainer, API) aura son propre fichier docker-compose.yml dans `/hebergement_serveur/config/docker-compose/`.

1. Pour Jenkins :
```yaml
version: '3'

services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    restart: always
    volumes:
      - /hebergement_serveur/data/jenkins:/var/jenkins_home
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jenkins.rule=Host(`jenkins.${DYNDNS_DOMAIN}`)"
      - "traefik.http.routers.jenkins.tls.certresolver=letsencrypt"

networks:
  traefik-public:
    external: true
```

2. Pour Portainer :
```yaml
version: '3'

services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /hebergement_serveur/data/portainer:/data
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`docker.${DYNDNS_DOMAIN}`)"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"

networks:
  traefik-public:
    external: true
```

### 1.5 Maintenance

Les logs de tous les services sont centralisés dans `/hebergement_serveur/logs/`.
Les certificats SSL sont gérés automatiquement par Traefik.

Pour surveiller les services :
```bash
# Voir tous les conteneurs
docker ps

# Voir les logs d'un service
docker logs -f [nom_du_conteneur]

# Redémarrer un service
docker-compose -f /hebergement_serveur/config/docker-compose/[service]/docker-compose.yml restart
```