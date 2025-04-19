# Guide de Configuration DynDNS avec l'API OVH

Ce guide détaille les étapes pour configurer et tester un service DynDNS en utilisant l'API OVH.

## Table des matières
1. [Prérequis](#prérequis)
2. [Première étape : Génération d'un nouveau token OVH](#première-étape-génération-dun-nouveau-token-ovh)
3. [Création des clés API OVH](#création-des-clés-api-ovh)
4. [Configuration des variables d'environnement](#configuration-des-variables-denvironnement)
5. [Configuration des enregistrements DNS](#configuration-des-enregistrements-dns)
6. [Test de l'API](#test-de-lapi)
7. [Gestion des permissions OVH API](#gestion-des-permissions-ovh-api)
8. [Gestion des TTL DNS](#gestion-des-ttl-dns)
9. [Configuration Traefik avec OVH](#configuration-traefik-avec-ovh)
10. [Configuration du sous-domaine Traefik](#configuration-du-sous-domaine-traefik)
11. [Configuration du challenge ACME DNS avec OVH](#configuration-du-challenge-acme-dns-avec-ovh)

## Prérequis

- Un domaine hébergé chez OVH (dans notre cas : iaproject.fr)
- Un compte OVH avec accès à l'espace client
- Python 3.x installé
- Les packages Python requis :
  ```bash
  pip install python-dotenv requests ovh
  ```

## Première étape : Génération d'un nouveau token OVH

1. **Utilisation du script get_new_token.py** :
   ```bash
   # Rendre le script exécutable
   chmod +x scripts/get_new_token.py

   # Exécuter le script
   ./scripts/get_new_token.py
   ```

2. **Permissions configurées automatiquement** :
   ```python
   access_rules = [
       # Lecture des informations de zone
       {'method': 'GET', 'path': '/domain/zone/*'},
       # Gestion des enregistrements DNS
       {'method': 'GET', 'path': '/domain/zone/*/record'},
       {'method': 'POST', 'path': '/domain/zone/*/record'},
       {'method': 'PUT', 'path': '/domain/zone/*/record/*'},
       {'method': 'DELETE', 'path': '/domain/zone/*/record/*'},
       # Rafraîchissement de la zone
       {'method': 'POST', 'path': '/domain/zone/*/refresh'}
   ]
   ```

## Configuration des variables d'environnement

Le fichier `.env` doit contenir les sections suivantes :

```env
# Variables API OVH (pour l'API REST)
OVH_APPLICATION_KEY=votre_ak
OVH_APPLICATION_SECRET=votre_as
OVH_CONSUMER_KEY=votre_ck
OVH_ENDPOINT=ovh-eu

# Variables Zone DNS
OVH_DNS_ZONE=iaproject.fr
OVH_DNS_RECORD_ID=5360565253
OVH_DNS_SUBDOMAIN=airquality

# Variables DynDNS
DYNDNS_USERNAME=iaproject.fr-identdns
DYNDNS_PASSWORD=votre_password
DYNDNS_UPDATE_INTERVAL=300
```

## Configuration des enregistrements DNS

### Configuration actuelle

Voici les enregistrements DNS actuellement configurés :

```yaml
# Enregistrement pour le service airquality
- Type: A
  Sous-domaine: airquality
  ID: 5360565253
  TTL: 60
  Cible: IP_DYNAMIQUE

# Enregistrement pour Traefik
- Type: A
  Sous-domaine: traefik
  TTL: 0
  Cible: IP_FIXE
```

### Mise à jour des enregistrements

Pour mettre à jour un enregistrement via l'API :

```bash
curl -X PUT "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/record/5360565253" \
     -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
     -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "ttl": 60,
       "target": "NOUVELLE_IP"
     }'
```

## Configuration Traefik avec OVH

### Configuration docker-compose.yml

```yaml
services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - traefik-public
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./acme.json:/opt/traefik/acme.json
      - ./dynamic:/etc/traefik/dynamic
    env_file:
      - ../.env
    environment:
      - TZ=Europe/Paris
      - OVH_ENDPOINT=${OVH_ENDPOINT:-ovh-eu}
      - OVH_APPLICATION_KEY=${OVH_APPLICATION_KEY}
      - OVH_APPLICATION_SECRET=${OVH_APPLICATION_SECRET}
      - OVH_CONSUMER_KEY=${OVH_CONSUMER_KEY}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.rule=Host(`traefik.iaproject.fr`)"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"
```

## Gestion des TTL DNS

### Valeurs recommandées

- TTL = 60 : Pour les sous-domaines DynDNS (ex: airquality.iaproject.fr)
- TTL = 0 : Pour les enregistrements statiques (ex: traefik.iaproject.fr)
- TTL = 3600 : Pour les enregistrements rarement modifiés

### Configuration actuelle

```yaml
# Sous-domaines dynamiques
airquality.iaproject.fr:    TTL: 60    Type: A    Cible: IP_DYNAMIQUE

# Sous-domaines statiques
traefik.iaproject.fr:       TTL: 0     Type: A    Cible: IP_FIXE
```

## Dépannage

### Commandes utiles

1. **Vérification DNS** :
   ```bash
   # Vérifier la résolution d'un sous-domaine
   dig @ns104.ovh.net airquality.iaproject.fr

   # Vérifier la propagation
   dig +trace airquality.iaproject.fr
   ```

2. **Vérification API** :
   ```bash
   # Tester la connectivité API
   curl -v https://eu.api.ovh.com/v1/auth/time

   # Vérifier un enregistrement
   curl -X GET "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/record/5360565253" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

3. **Logs Traefik** :
   ```bash
   # Suivre les logs en temps réel
   docker logs -f traefik
   ```

### Erreurs courantes

1. **Invalid signature (400)**
   - Vérifier les credentials dans le fichier .env
   - S'assurer que l'horloge du système est synchronisée

2. **This call has not been granted (403)**
   - Régénérer un Consumer Key avec les bonnes permissions
   - Vérifier que toutes les permissions nécessaires sont accordées

3. **DNS problem: NXDOMAIN**
   - Vérifier que l'enregistrement existe dans la zone DNS
   - Attendre la propagation DNS (jusqu'à 24h)
   - Vérifier que l'IP cible est correcte

## Configuration finale et bonnes pratiques

### Configuration optimale pour Traefik

#### 1. Structure du fichier docker-compose.yml
```yaml
# version: '3'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"  # Port 2222 externe vers 22 interne
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./acme.json:/letsencrypt/acme.json
      - ./dynamic:/etc/traefik/dynamic
    env_file:
      - ../.env
    environment:
      - TZ=Europe/Paris
      - OVH_ENDPOINT
      - OVH_APPLICATION_KEY
      - OVH_APPLICATION_SECRET
      - OVH_CONSUMER_KEY
      - OVH_DNS_ZONE
      - OVH_DNS_SUBDOMAIN
      - TRAEFIK_BASIC_AUTH=${TRAEFIK_BASIC_AUTH}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.rule=Host(`traefik.iaproject.fr`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth-basic"
      - "traefik.http.middlewares.auth-basic.basicauth.users=${TRAEFIK_BASIC_AUTH}"

networks:
  proxy:
    external: true
```

#### 2. Configuration traefik.yml
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
    http:
      tls: {}  # Pour certificat auto-signé temporaire
      # Pour Let's Encrypt, utiliser:
      # tls:
      #   certResolver: letsencrypt
  ssh:
    address: ":2222"

# Configuration des certificats
certificatesResolvers:
  letsencrypt:
    acme:
      email: contact@iaproject.fr
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

# Configuration des providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

# Configuration du dashboard
api:
  dashboard: true
  insecure: true  # Mettre à false en production
  debug: true

# Configuration des logs
log:
  level: DEBUG  # INFO en production
  format: common
```

### Génération du hash pour l'authentification basique

1. **Utilisation d'un conteneur Apache temporaire** :
   ```bash
   docker run --rm httpd:2.4-alpine htpasswd -nb admin votremotdepasse
   ```

2. **Pour échapper les caractères $ dans docker-compose** :
   ```bash
   echo 'admin:$(docker run --rm httpd:2.4-alpine htpasswd -nb admin votremotdepasse | cut -d ":" -f 2)' | sed -e s/\\$/\\$\\$/g
   ```

3. **Configuration dans le fichier .env** :
   ```
   # Identifiants Traefik
   TRAEFIK_BASIC_AUTH=admin:$$apr1$$votrehashici
   ```
   Note: Les $ doivent être doublés dans le fichier .env pour échapper ce caractère spécial.

### Gestion des certificats Let's Encrypt

1. **Limites de Let's Encrypt** :
   - Maximum 5 certificats par domaine toutes les 7 jours
   - Message d'erreur typique: `too many certificates (5) already issued for this exact set of domains in the last 168h0m0s`

2. **Solutions temporaires** :
   - Utiliser un certificat auto-signé comme montré dans les configurations ci-dessus
   - Configurer le mode insecure pour les tests (api.insecure: true)

3. **Réactiver Let's Encrypt** :
   - Dans traefik.yml :
     ```yaml
     websecure:
       address: ":443"
       http:
         tls:
           certResolver: letsencrypt
     ```
   - Dans docker-compose.yml :
     ```yaml
     - "traefik.http.routers.traefik.tls.certResolver=letsencrypt"
     ```
   - Dans les fichiers dynamic : vérifier qu'aucun n'utilise certResolver

### Middlewares et Configuration dynamique

1. **Organisation recommandée** :
   - security.yml : pour les middlewares de sécurité réutilisables
   - dashboard.yml : pour la configuration spécifique du dashboard

2. **Référence correcte des middlewares** :
   - Format: `middleware-name@provider`
   - Exemple: `secure-headers@file` pour un middleware défini dans un fichier

3. **Résolution des problèmes courants** :
   - Incohérence de nommage : vérifier que les noms des middlewares sont cohérents entre les références
   - Middlewares redondants : éviter de définir le même middleware à plusieurs endroits
   - Erreur `middleware not found` : vérifier le nom et le provider du middleware