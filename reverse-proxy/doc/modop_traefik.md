# Guide d'utilisation de Traefik

## 1. Introduction

### 1.1 Qu'est-ce que Traefik ?
Traefik est un reverse proxy et un load balancer moderne conçu pour le cloud. Il gère automatiquement :
- Le routage des requêtes vers les services
- La terminaison SSL/TLS avec Let's Encrypt
- L'équilibrage de charge
- Les middlewares (authentification, rate limiting, etc.)

### 1.2 Avantages
- Configuration automatique via Docker labels
- Gestion automatique des certificats SSL/TLS
- Interface de monitoring (dashboard)
- Haute performance et faible empreinte mémoire

## 2. Architecture des fichiers

```
reverse-proxy/
├── docker-compose.yml          # Configuration Docker production
├── docker-compose.dev.yml      # Configuration Docker développement
├── traefik.yml                # Configuration Traefik production
├── traefik.dev.yml            # Configuration Traefik développement
├── acme.json                  # Stockage des certificats (généré automatiquement)
├── dynamic/                   # Configuration dynamique
│   ├── auth.yml              # Configuration authentification
│   ├── security.yml          # Configuration sécurité
│   ├── services.yml          # Configuration services production
│   ├── services.dev.yml      # Configuration services développement
│   ├── redirects.yml         # Configuration redirections
│   └── users.txt             # Fichier des utilisateurs (htpasswd)
└── doc/
    └── modop_traefik.md      # Ce guide
```

## 3. Configuration des environnements

### 3.1 Production
- Utilise HTTPS avec Let's Encrypt
- Domaines en `.iaproject.fr`
- Certificats SSL automatiques
- Sécurité renforcée

### 3.2 Développement
- HTTP uniquement
- Domaines en `.localhost`
- Pas de certificats
- Configuration simplifiée

## 4. Déploiement

### 4.1 Prérequis serveur
- Docker et Docker Compose installés
- Ports 80 et 443 ouverts
- Domaines DNS configurés vers l'IP du serveur

### 4.2 Installation sur le serveur
1. Créer la structure des dossiers :
```bash
mkdir -p /hebergement_serveur/reverse-proxy/{dynamic,doc}
chmod 700 /hebergement_serveur/reverse-proxy
```

2. Copier les fichiers :
```bash
scp -r * user@server:/hebergement_serveur/reverse-proxy/
```

3. Créer et configurer acme.json :
```bash
touch /hebergement_serveur/reverse-proxy/acme.json
chmod 600 /hebergement_serveur/reverse-proxy/acme.json
```

4. Créer les réseaux Docker :
```bash
docker network create proxy
docker network create traefik-public
```

### 4.3 Démarrage des services

Production :
```bash
cd /hebergement_serveur/reverse-proxy
docker-compose up -d
```

Développement :
```bash
cd /hebergement_serveur/reverse-proxy
docker-compose -f docker-compose.dev.yml up -d
```

## 5. Configuration des services

### 5.1 Labels Docker
Pour ajouter un nouveau service, utilisez ces labels dans votre docker-compose.yml :

```yaml
services:
  myapp:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.iaproject.fr`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

### 5.2 Configuration dynamique
Ou ajoutez le service dans `dynamic/services.yml` :

```yaml
http:
  routers:
    myapp:
      rule: "Host(`myapp.iaproject.fr`)"
      entryPoints:
        - "websecure"
      service: "myapp"
      tls:
        certResolver: "letsencrypt"
  services:
    myapp:
      loadBalancer:
        servers:
          - url: "http://myapp:8080"
```

## 6. Surveillance et maintenance

### 6.1 Logs
```bash
# Logs en temps réel
docker logs -f traefik

# Logs des certificats
docker logs traefik | grep -A1 letsencrypt
```

### 6.2 Dashboard
Accessible sur : https://traefik.iaproject.fr/dashboard/
- Authentification requise (users.txt)
- Vue d'ensemble des services
- État des certificats

### 6.3 Renouvellement des certificats
- Automatique par Traefik
- 30 jours avant expiration
- Stockés dans acme.json

### 6.4 Sauvegarde
Fichiers à sauvegarder :
- acme.json (certificats)
- dynamic/* (configuration)
- docker-compose.yml
- .env (variables d'environnement)

## 7. Résolution des problèmes

### 7.1 Certificats
Si problèmes avec les certificats :
```bash
# Forcer le renouvellement
mv acme.json acme.json.old
touch acme.json
chmod 600 acme.json
docker-compose restart traefik
```

### 7.2 Connectivité
Vérifier :
- DNS (dig domain.iaproject.fr)
- Ports (netstat -tulpn)
- Logs (docker logs traefik)

### 7.3 Services
Si un service n'est pas accessible :
1. Vérifier les labels Docker
2. Contrôler la configuration dans services.yml
3. Tester la santé du service
4. Vérifier les logs

## 8. Sécurité

### 8.1 Bonnes pratiques
- Toujours utiliser HTTPS en production
- Maintenir les permissions strictes sur acme.json
- Utiliser des mots de passe forts pour le dashboard
- Activer les middlewares de sécurité

### 8.2 Middlewares recommandés
- rate-limit : limite le nombre de requêtes
- secure-headers : en-têtes de sécurité HTTP
- ip-whitelist : restriction par IP
- auth-basic : authentification basique

## 9. Développement local

### 9.1 Configuration hosts
Exemple de configuration complète du fichier hosts :
- Linux : `/etc/hosts`
- Windows : `C:\Windows\System32\drivers\etc\hosts`

```bash
# Configuration IPv4 de base
127.0.0.1    localhost
127.0.1.1    worker1

# Services Traefik en développement local
127.0.0.1    airquality.localhost
127.0.0.1    grafana.localhost
127.0.0.1    prometheus.localhost
127.0.0.1    portainer.localhost

# Configuration IPv6
::1          ip6-localhost ip6-loopback
fe00::0      ip6-localnet
ff00::0      ip6-mcastprefix
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
```

Notes importantes :
- Ne modifiez pas les entrées IPv6 existantes
- Ajoutez vos services sous la section IPv4
- Redémarrez votre navigateur après modification
- Sous Windows, éditez le fichier en tant qu'administrateur
- Sous Linux, utilisez `sudo` pour éditer le fichier

Pour vérifier que la résolution DNS fonctionne :
```bash
# Test de résolution IPv4
ping airquality.localhost

# Test de résolution IPv6
ping6 ip6-localhost
```

### 9.2 Tests locaux

#### 9.2.1 Vérification de la configuration
```bash
# Vérifier la syntaxe de la configuration
docker-compose -f docker-compose.dev.yml config

# Vérifier les réseaux Docker
docker network ls | grep -E 'proxy|traefik'

# Vérifier les variables d'environnement
docker-compose -f docker-compose.dev.yml config | grep -A 10 environment
```

#### 9.2.2 Démarrage et tests
```bash
# Démarrer les services
docker-compose -f docker-compose.dev.yml up -d

# Vérifier l'état des conteneurs
docker-compose -f docker-compose.dev.yml ps

# Vérifier les logs de Traefik
docker-compose -f docker-compose.dev.yml logs traefik

# Tester l'accès aux services
curl -H "Host: airquality.localhost" http://localhost
curl -H "Host: grafana.localhost" http://localhost
curl -H "Host: prometheus.localhost" http://localhost
curl -H "Host: portainer.localhost" http://localhost
```

#### 9.2.3 Debugging
```bash
# Vérifier les routes Traefik
docker exec traefik-dev traefik healthcheck

# Vérifier la configuration active
docker exec traefik-dev traefik show config

# Vérifier la connectivité réseau
docker network inspect proxy
docker network inspect traefik-public

# Vérifier les logs en temps réel
docker-compose -f docker-compose.dev.yml logs -f
```

#### 9.2.4 Tests dans le navigateur
1. Ouvrir les URLs suivantes :
   - http://airquality.localhost
   - http://grafana.localhost
   - http://prometheus.localhost
   - http://portainer.localhost

2. Vérifier dans les DevTools :
   - Onglet Network pour les redirections
   - Console pour les erreurs JavaScript
   - Application pour les cookies/storage

3. En cas d'erreur :
   - Vérifier que le service est démarré
   - Contrôler les logs du service
   - Vérifier la résolution DNS locale
   - Tester avec curl en mode verbose :
     ```bash
     curl -v -H "Host: airquality.localhost" http://localhost
     ```