# Guide de Configuration DynDNS avec l'API OVH

Ce guide détaille les étapes pour configurer et tester un service DynDNS en utilisant l'API OVH.

## Table des matières
1. [Prérequis](#prérequis)
2. [Première étape : Génération d'un nouveau token OVH](#première-étape-génération-d'un-nouveau-token-ovh)
3. [Création des clés API OVH](#création-des-clés-api-ovh)
4. [Configuration des enregistrements DNS](#configuration-des-enregistrements-dns)
5. [Test de l'API](#test-de-lapi)
6. [Exemples de tests réalisés](#exemples-de-tests-réalisés)
7. [Dépannage](#dépannage)
8. [Gestion des permissions OVH API](#gestion-des-permissions-ovh-api)
9. [Gestion des Tokens dans la Console OVH](#gestion-des-tokens-dans-la-console-ovh)
10. [Gestion des TTL DNS](#gestion-des-ttl-dns)
11. [Configuration Traefik avec OVH](#configuration-traefik-avec-ovh)

## Prérequis

- Un domaine hébergé chez OVH
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

2. **Le script va** :
   - Créer un nouveau token avec les permissions nécessaires
   - Générer une URL de validation
   - Afficher les instructions pour finaliser l'authentification

3. **Permissions configurées automatiquement** :
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

4. **Instructions après exécution** :
   - Visiter l'URL de validation fournie
   - Se connecter avec son compte OVH
   - Accepter les droits demandés
   - Mettre à jour le fichier .env avec la nouvelle Consumer Key

5. **Vérification** :
   ```bash
   # Vérifier que le token fonctionne
   python scripts/test_ovh_api.py
   ```

> **Important** : Cette étape doit être effectuée avant toute configuration de Traefik ou de DynDNS, car elle fournit les permissions nécessaires pour les deux services.

## Création des clés API OVH

1. Connectez-vous à l'espace client OVH
2. Allez sur https://eu.api.ovh.com/createApp/
3. Remplissez les informations :
   - Nom de l'application : "DynDNS server"
   - Description : "Gestion DNS dynamique"
4. Notez les credentials fournis :
   - Application Key (AK)
   - Application Secret (AS)

> **Note importante** : Lors de la demande de DynDNS dans l'interface OVH, ne remplissez PAS le champ Consumer Key (CK). Ce champ sera automatiquement généré et rempli par OVH. Si vous entrez une valeur manuellement, cela pourrait causer des problèmes d'authentification.

## Configuration des variables d'environnement

Le fichier `.env` est organisé en plusieurs sections pour éviter les conflits :

1. **Variables API OVH** (pour l'API REST) :
   ```env
   OVH_APPLICATION_KEY=votre_ak
   OVH_APPLICATION_SECRET=votre_as
   OVH_CONSUMER_KEY=votre_ck
   OVH_API_ENDPOINT=https://eu.api.ovh.com/v1
   ```

2. **Variables Zone DNS** (pour la gestion via API) :
   ```env
   OVH_DNS_ZONE=votre_domaine.fr
   OVH_DNS_RECORD_ID=id_enregistrement
   OVH_DNS_SUBDOMAIN=sous_domaine
   ```

3. **Variables DynDNS** (pour les clients DynDNS comme ddclient) :
   ```env
   DYNDNS_USERNAME=votre_domaine-identdns
   DYNDNS_PASSWORD=votre_password
   DYNDNS_UPDATE_INTERVAL=300
   DYNDNS_ADDITIONAL_SUBDOMAINS=www,autres_sous_domaines
   ```

> **Important** : Ne pas confondre les variables OVH_DNS_* (utilisées pour l'API REST) avec les variables DYNDNS_* (utilisées pour le protocole DynDNS).

## Configuration des enregistrements DNS

1. Dans l'espace client OVH :
   - Allez dans "Zone DNS"
   - Sélectionnez votre domaine
   - Vérifiez qu'il n'y a pas de doublons d'enregistrements

2. Via l'API (console) :
   - Accédez à https://eu.api.ovh.com/console/
   - Authentifiez-vous avec vos clés API
   - Utilisez l'endpoint : `/domain/zone/{zoneName}/record`

3. Création d'un enregistrement A :
   ```bash
   # Obtenir l'IP publique
   curl https://api.ipify.org

   POST /domain/zone/{zoneName}/record
   {
     "fieldType": "A",
     "subDomain": "votre-sous-domaine",
     "target": "votre-ip_publique",
     "ttl": 0
   }
   ```

## Test de l'API

1. Générer un Consumer Key :
   ```bash
   python generate_consumer_key.py
   ```

2. Configurer le fichier .env :
   ```env
   OVH_APPLICATION_KEY=votre_ak
   OVH_APPLICATION_SECRET=votre_as
   OVH_CONSUMER_KEY=votre_ck
   ```

3. Tester la connexion :
   ```bash
   python test_ovh_api.py
   ```

4. Vérifier les enregistrements :
   ```bash
   # Liste tous les enregistrements
   GET /domain/zone/{zoneName}/record

   # Filtre par sous-domaine
   GET /domain/zone/{zoneName}/record?fieldType=A&subDomain=votre-sous-domaine
   ```

5. Rafraîchir la zone après modifications :
   ```bash
   POST /domain/zone/{zoneName}/refresh
   ```

## Exemples de tests réalisés

### 1. Vérification des credentials API

```bash
GET /me/api/credential

Résultat :
[
  "591668583",
  // ... (20 credentials différents listés)
]
```

### 2. Vérification des enregistrements DNS

```bash
GET /domain/zone/iaproject.fr/record

Résultat : 6 enregistrements trouvés, dont :
{
  "fieldType": "A",
  "id": 5360565253,
  "subDomain": "airquality",
  "target": "164.132.235.17",
  "ttl": 0,
  "zone": "iaproject.fr"
}
```

### 3. Test de l'authentification DynDNS

```bash
GET /domain/zone/iaproject.fr/dynHost/record

Résultat :
{
  "login": "iaproject.fr-identdns",
  "subDomain": "airquality",
  "zone": "iaproject.fr"
}
```

### 4. Vérification des informations du domaine

```bash
GET /domain/iaproject.fr

Résultat :
{
  "serviceId": 127377739,
  "domain": "iaproject.fr",
  "creation": "2024-07-05",
  "expiration": "2025-07-05",
  "contactAdmin": "df1257137-ovh",
  "contactBilling": "df1257137-ovh",
  "contactTech": "df1257137-ovh",
  "status": "ok"
}
```

### 5. Vérification détaillée du service

```bash
GET /domain/-serviceName-

Résultat :
{
  "domain": "iaproject.fr",
  "serviceId": 127377752,
  "state": "ok",
  "nameServerType": "hosting",
  "nameServers": [
    {
      "id": 102633187,
      "nameServerType": "hosting",
      "nameServer": "dns104.ovh.net"
    },
    {
      "id": 102633188,
      "nameServerType": "hosting",
      "nameServer": "ns104.ovh.net"
    }
  ],
  "dnssecState": "enabled"
}
```

### 6. Vérification des capacités de la zone

```bash
GET /domain/zone/iaproject.fr/capabilities

Résultat :
{
  "dynHost": true
}
```

### 7. Mise à jour de l'enregistrement DNS

```bash
PUT /domain/zone/iaproject.fr/record/5360565253

Body :
{
  "subDomain": "airquality",
  "target": "91.173.110.4",
  "ttl": 60
}

Suivi de :
POST /domain/zone/iaproject.fr/refresh
```

### 8. Création réussie de la clé API avec les droits corrects

```bash
# Création d'une nouvelle clé API avec les droits appropriés
Application Key : 5cdd1***
Application Secret : 6a7bb***
Consumer Key : 5c23c***

# Test de validation avec les droits
GET /domain/zone/iaproject.fr/record/5360565253

Résultat :
{
  "fieldType": "A",
  "id": 5360565253,
  "subDomain": "airquality",
  "target": "91.17***",
  "ttl": 60,
  "zone": "iaproject.fr"
}

# Droits configurés et validés :
- GET /domain/zone/*/record
- PUT /domain/zone/*/record/*
- POST /domain/zone/*/refresh

# Validation de la configuration :
- Test de connexion à l'API : Succès
- Lecture de l'enregistrement DNS : Succès
- Configuration du TTL : 60 secondes (optimal pour les mises à jour dynamiques)
- Cible actuelle : IP publique du serveur (91.17***)
```

## Dépannage

### Erreurs courantes

1. **Invalid signature (400)**
   - Vérifiez le timestamp
   - Assurez-vous que l'URL est correcte (v1 et non 1.0)
   - Vérifiez les credentials

2. **This service does not exist (404)**
   - Vérifiez le nom de domaine
   - Confirmez que la zone DNS existe

3. **This call has not been granted (403)**
   - Régénérez un Consumer Key
   - Vérifiez les permissions

### Commandes de vérification

1. Vérifier la résolution DNS :
   ```bash
   dig @ns104.ovh.net votre-sous-domaine.votre-domaine.fr
   ```

2. Vérifier la propagation :
   ```bash
   dig +trace votre-sous-domaine.votre-domaine.fr
   ```

3. Tester la connectivité :
   ```bash
   curl -v https://eu.api.ovh.com/v1/auth/time
   ```

## Gestion des permissions OVH API

### 1. Vérification des permissions actuelles

1. **Liste des permissions** :
   ```bash
   # Vérifier les permissions de l'application
   curl -X GET "https://eu.api.ovh.com/1.0/auth/currentCredential" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

2. **Permissions requises pour DynDNS et Traefik** :
   - GET /domain/zone/*
   - PUT /domain/zone/*
   - POST /domain/zone/*
   - DELETE /domain/zone/*
   - GET /domain/zone/*/record
   - PUT /domain/zone/*/record/*
   - POST /domain/zone/*/refresh

### 2. Création d'une nouvelle application

1. **Script de création** :
   ```python
   import ovh
   import logging
   from config import setup_logger

   logger = setup_logger(__name__)

   def create_ovh_app():
       try:
           client = ovh.Client(
               endpoint='ovh-eu',
               application_key='votre_application_key',
               application_secret='votre_application_secret'
           )

           access_rules = [
               {'method': 'GET', 'path': '/domain/zone/*'},
               {'method': 'PUT', 'path': '/domain/zone/*'},
               {'method': 'POST', 'path': '/domain/zone/*'},
               {'method': 'DELETE', 'path': '/domain/zone/*'},
               {'method': 'GET', 'path': '/domain/zone/*/record'},
               {'method': 'PUT', 'path': '/domain/zone/*/record/*'},
               {'method': 'POST', 'path': '/domain/zone/*/refresh'}
           ]

           result = client.request_consumerkey(access_rules)

           logger.info("Nouvelle application créée avec succès")
           logger.info(f"Consumer Key: {result['consumerKey']}")
           logger.info(f"URL de validation: {result['validationUrl']}")

           return result
       except Exception as e:
           logger.error(f"Erreur lors de la création de l'application: {str(e)}")
           raise
   ```

2. **Procédure de création** :
   - Exécuter le script
   - Visiter l'URL de validation
   - Noter le nouveau Consumer Key
   - Mettre à jour le fichier .env

## Gestion des Tokens dans la Console OVH

### 1. Accès à la liste des tokens

1. **Via l'interface web** :
   - Connectez-vous à votre compte OVH
   - Allez dans "API" > "Mes applications"
   - URL directe : https://www.ovh.com/auth/api/credentials

2. **Via l'API** :
   ```bash
   # Liste de tous les tokens
   curl -X GET "https://eu.api.ovh.com/1.0/auth/credential" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

### 2. Analyse des tokens

1. **Informations affichées pour chaque token** :
   - ID du token
   - Date de création
   - Date d'expiration
   - Droits accordés
   - État (actif/inactif)
   - Application associée

2. **Vérification des droits** :
   ```bash
   # Pour chaque token, vérifier les droits
   curl -X GET "https://eu.api.ovh.com/1.0/auth/credential/{credentialId}" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

### 3. Suppression des tokens

1. **Via l'interface web** :
   - Dans "API" > "Mes applications"
   - Cliquez sur le token à supprimer
   - Cliquez sur "Supprimer"
   - Confirmez la suppression

2. **Via l'API** :
   ```bash
   # Suppression d'un token spécifique
   curl -X DELETE "https://eu.api.ovh.com/1.0/auth/credential/{credentialId}" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

## Gestion des TTL DNS

### 1. Comprendre les TTL

1. **Définition du TTL** :
   - Time To Live (durée de vie) en secondes
   - Détermine le temps de mise en cache des enregistrements DNS
   - Impact la vitesse de propagation des changements

2. **Valeurs recommandées** :
   - TTL = 60 : Pour les sous-domaines DynDNS (IP changeante)
   - TTL = 0 : Pour les enregistrements statiques (IP fixe)
   - TTL = 3600 : Pour les enregistrements rarement modifiés

### 2. Configuration des TTL

1. **Via l'interface OVH** :
   - Zone DNS > Sélectionner l'enregistrement
   - Modifier le TTL
   - Exemple :
     ```
     airquality.iaproject.fr    TTL: 60    Type: A    Cible: IP_DYNAMIQUE
     www.iaproject.fr          TTL: 0     Type: A    Cible: IP_FIXE
     ```

2. **Via l'API** :
   ```bash
   # Mise à jour du TTL pour un enregistrement DynDNS
   curl -X PUT "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/record/5360565253" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "ttl": 60,
          "target": "IP_ACTUELLE"
        }'
   ```

## Configuration Traefik avec OVH

### 1. Configuration du docker-compose.yml

```yaml
services:
  traefik:
    environment:
      - OVH_ENDPOINT=${OVH_ENDPOINT}
      - OVH_APPLICATION_KEY=${OVH_APPLICATION_KEY}
      - OVH_APPLICATION_SECRET=${OVH_APPLICATION_SECRET}
      - OVH_CONSUMER_KEY=${OVH_CONSUMER_KEY}
    env_file:
      - ../.env
```

### 2. Vérification des variables d'environnement

```bash
# Vérifier que les variables sont bien chargées
docker compose config
```

### 3. Vérification des logs Traefik

```bash
# Vérifier les logs pour détecter les erreurs
docker logs traefik
```

### 4. Contrôles de sécurité

- Vérifier que le fichier acme.json a les bonnes permissions (600)
- S'assurer que les variables d'environnement sont correctement définies
- Vérifier que le Consumer Key a les permissions nécessaires

### 5. Dépannage des permissions

1. **Erreurs courantes** :
   - "This call has not been granted" : Permissions manquantes
   - "Invalid signature" : Clés API incorrectes
   - "Resource not found" : Mauvais endpoint
   - "Unable to obtain ACME certificate" : Problème de permissions OVH

2. **Solutions** :
   - Vérifier les permissions dans l'interface OVH
   - Régénérer les clés API avec les bonnes permissions
   - Mettre à jour le Consumer Key
   - Vérifier que les variables d'environnement sont correctement chargées

3. **Vérification des logs** :
   ```bash
   # Vérifier les logs d'erreur
   docker logs traefik
   ```

### 6. Bonnes pratiques

1. **Sécurité** :
   - Ne jamais exposer les clés API dans le code
   - Utiliser des variables d'environnement
   - Limiter les permissions au strict nécessaire
   - Vérifier régulièrement les logs pour détecter les tentatives d'accès non autorisées

2. **Maintenance** :
   - Garder une trace des modifications de permissions
   - Documenter les changements de configuration
   - Tester régulièrement la configuration
   - Mettre à jour la documentation en cas de changement

3. **Monitoring** :
   - Surveiller les logs Traefik
   - Vérifier la validité des certificats
   - Tester régulièrement la résolution DNS
   - Vérifier la propagation des changements