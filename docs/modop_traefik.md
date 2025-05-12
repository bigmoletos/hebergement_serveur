# Guide de déploiement Traefik

## Prérequis
- Docker et Docker Compose installés
- Accès aux ports 80, 443 et 2222
- Nom de domaine configuré (*.airquality.iaproject.fr)

## Configuration des réseaux Docker
1. Exécuter le script de configuration des réseaux :
```bash
chmod +x scripts/setup_networks.sh
./scripts/setup_networks.sh
```

## Déploiement de Traefik
1. Créer les dossiers nécessaires :
```bash
mkdir -p reverse-proxy/acme
mkdir -p reverse-proxy/dynamic
```

2. Vérifier les configurations :
- `reverse-proxy/traefik.prod.yml` : Configuration principale
- `reverse-proxy/dynamic/dashboard.yml` : Configuration du dashboard
- `config/docker-compose/docker-compose.yml` : Configuration Docker Compose

3. Démarrer Traefik :
```bash
cd config/docker-compose
docker-compose up -d
```

4. Vérifier le statut :
```bash
docker ps
docker logs traefik
```

## Vérification du déploiement
1. Accéder au dashboard : https://traefik.airquality.iaproject.fr
2. Vérifier les certificats SSL dans /etc/traefik/acme/acme.json
3. Tester les redirections HTTP vers HTTPS

## Résolution des problèmes courants
1. Problèmes de certificats :
   - Vérifier les permissions du dossier acme
   - Vérifier les logs Traefik pour les erreurs Let's Encrypt

2. Problèmes de réseau :
   - Vérifier que les réseaux Docker existent
   - Vérifier les règles de pare-feu

3. Problèmes d'accès :
   - Vérifier la configuration DNS
   - Vérifier les middlewares d'authentification