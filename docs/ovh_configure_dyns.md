# Guide de Configuration DynDNS avec l'API OVH

Ce guide détaille les étapes pour configurer et tester un service DynDNS en utilisant l'API OVH.

## Table des matières
1. [Prérequis](#prérequis)
2. [Création des clés API OVH](#création-des-clés-api-ovh)
3. [Configuration des enregistrements DNS](#configuration-des-enregistrements-dns)
4. [Test de l'API](#test-de-lapi)
5. [Exemples de tests réalisés](#exemples-de-tests-réalisés)
6. [Dépannage](#dépannage)
7. [Débogage ddclient](#débogage-ddclient)
8. [Vérification manuelle de la configuration](#vérification-manuelle-de-la-configuration)
9. [Configuration SSH](#configuration-ssh)
10. [Configuration SSH Freebox](#configuration-ssh-freebox)
11. [Gestion des permissions OVH API](#gestion-des-permissions-ovh-api)
12. [Gestion des Tokens dans la Console OVH](#gestion-des-tokens-dans-la-console-ovh)
13. [Gestion des TTL DNS](#gestion-des-ttl-dns)

## Prérequis

- Un domaine hébergé chez OVH
- Un compte OVH avec accès à l'espace client
- Python 3.x installé
- Les packages Python requis :
  ```bash
  pip install python-dotenv requests
  ```

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
   
   https://eu.api.ovh.com/console/?section=%2Fauth&branch=v1#get-/auth/details

   - Authentifiez-vous avec vos clés API
   - Utilisez l'endpoint : `/domain/zone/{zoneName}/record`

3. Création d'un enregistrement A :
   ```bash

 #  obtenir l'IP publique
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

### Notes importantes sur les tests

1. **IP de redirection** :
   - IP initiale (serveur OVH) : 164.132.235.17
   - IP publique locale : 91.173.110.4
   - IP locale (non utilisable directement) : 192.168.1.134

2. **Configuration DynDNS** :
   - Username : iaproject.fr-identdns
   - Intervalle de mise à jour : 300 secondes
   - Serveur DynDNS : www.ovh.com

3. **Points de vigilance** :
   - Ne pas utiliser d'IP locale dans les enregistrements DNS
   - Toujours rafraîchir la zone après modification
   - Vérifier les TTL pour la propagation

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

## Bonnes pratiques

1. **Sécurité**
   - Ne partagez jamais vos credentials
   - Utilisez des variables d'environnement
   - Limitez les permissions du Consumer Key

2. **Performance**
   - Utilisez un TTL de 0 pour les mises à jour rapides
   - Évitez les requêtes inutiles
   - Mettez en cache les réponses quand possible

3. **Maintenance**
   - Surveillez les logs
   - Vérifiez régulièrement les enregistrements
   - Documentez les modifications

## Ressources utiles

- [Documentation API OVH](https://docs.ovh.com/fr/api/)
- [Console API OVH](https://eu.api.ovh.com/console/)
- [Guide DynDNS OVH](https://docs.ovh.com/fr/domains/utilisation-dynhost/)

## Débogage ddclient

### Erreur d'authentification

Si vous rencontrez cette erreur :
```
FAILED: {"class":"Client::Unauthorized","message":"..."}
```

Solutions possibles :

1. **Vérification de la configuration ddclient** :
   ```bash
   # Configuration correcte pour OVH
   protocol=dyndns2
   use=web
   ssl=yes
   server=www.ovh.com
   login=votre_domaine-identdns     # Format exact requis
   password='votre_mot_de_passe'
   zone=votre_domaine.fr            # Ajout de la zone
   ```

2. **Test manuel de l'authentification** :
   ```bash
   # Test via curl
   curl -v "https://www.ovh.com/nic/update?system=dyndns&hostname=airquality.iaproject.fr&myip=$(curl -s https://api.ipify.org)" \
   --user "iaproject.fr-identdns:votre_mot_de_passe"
   ```

3. **Vérification des logs** :
   ```bash
   sudo tail -f /var/log/ddclient.log
   sudo journalctl -u ddclient -f
   ```

### Configuration recommandée

Voici la configuration complète recommandée pour `/etc/ddclient.conf` :

```conf
# Configuration générale
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
ssl=yes

# Configuration OVH
protocol=dyndns2
use=web
server=www.ovh.com
login=iaproject.fr-identdns
password='+-*/2000Dns/*-+'
zone=iaproject.fr
airquality.iaproject.fr
```

### Procédure de redémarrage

Après modification de la configuration :
```bash
# Arrêt du service
sudo systemctl stop ddclient

# Vérification de la configuration
sudo ddclient -daemon=0 -debug -verbose -noquiet

# Redémarrage du service
sudo systemctl restart ddclient

# Vérification du statut
sudo systemctl status ddclient
```

### Points de vérification

1. **Format du login** :
   - Doit être exactement : `domaine-identdns`
   - Exemple : `iaproject.fr-identdns`

2. **Nom d'hôte complet** :
   - Doit inclure le domaine complet
   - Exemple : `airquality.iaproject.fr`

3. **Permissions des fichiers** :
   ```bash
   sudo chown root:root /etc/ddclient.conf
   sudo chmod 600 /etc/ddclient.conf
   ```

4. **Vérification de la résolution DNS** :
   ```bash
   dig airquality.iaproject.fr
   host airquality.iaproject.fr
   ```

## Vérification manuelle de la configuration

### 1. Vérification des tokens OVH

1. **Liste des tokens actifs** :
   ```bash
   # Liste tous les tokens
   curl -X GET "https://eu.api.ovh.com/1.0/auth/currentCredential" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

2. **Suppression des tokens inutiles** :
   ```bash
   # Suppression d'un token spécifique
   curl -X DELETE "https://eu.api.ovh.com/1.0/auth/currentCredential" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

### 2. Vérification de la configuration Freebox

1. **Vérification de l'IP publique** :
   ```bash
   # IP publique actuelle
   curl -s https://api.ipify.org

   # Comparer avec l'IP dans OVH
   dig +short airquality.iaproject.fr
   ```

2. **Vérification des redirections de port** :
   ```bash
   # Liste des redirections configurées
   curl -s "http://mafreebox.freebox.fr/api/v8/fw/redir/" \
        -H "X-Fbx-App-Auth: $FREEBOX_APP_TOKEN"
   ```

3. **Vérification de la configuration DynDNS Freebox** :
   ```bash
   # Configuration DynDNS
   curl -s "http://mafreebox.freebox.fr/api/v8/ddns/config/" \
        -H "X-Fbx-App-Auth: $FREEBOX_APP_TOKEN"
   ```

### 3. Vérification de la résolution DNS

1. **Test de résolution directe** :
   ```bash
   # Résolution DNS
   dig +short airquality.iaproject.fr

   # Test de propagation
   dig +trace airquality.iaproject.fr
   ```

2. **Test de connectivité** :
   ```bash
   # Test de connexion au serveur
   curl -v https://airquality.iaproject.fr

   # Vérification des en-têtes
   curl -I https://airquality.iaproject.fr
   ```

### 4. Vérification des logs

1. **Logs OVH** :
   ```bash
   # Vérification des dernières actions
   cat /var/log/ovh_dns.log
   ```

2. **Logs Freebox** :
   ```bash
   # Accès aux logs via l'interface web
   # http://mafreebox.freebox.fr/log/
   ```

### 5. Procédure de vérification complète

1. **Vérification initiale** :
   - IP publique Freebox
   - Configuration DynDNS Freebox
   - Redirections de port
   - Résolution DNS

2. **Test de mise à jour** :
   ```bash
   # Forcer une mise à jour
   /usr/local/bin/update_dns.py

   # Vérifier la nouvelle IP
   dig +short airquality.iaproject.fr
   ```

3. **Vérification finale** :
   - Temps de propagation DNS
   - Accessibilité du service
   - Stabilité de la connexion

### 6. Dépannage courant

1. **Problèmes de résolution DNS** :
   - Vérifier les serveurs DNS
   - Tester avec différents résolveurs
   - Vérifier le TTL

2. **Problèmes de redirection** :
   - Vérifier les règles de pare-feu
   - Tester la connectivité locale
   - Vérifier les logs Freebox

3. **Problèmes DynDNS** :
   - Vérifier les credentials
   - Tester la connexion API
   - Vérifier les permissions

## Configuration SSH

### 1. Génération des clés SSH

1. **Générer une nouvelle paire de clés** :
   ```bash
   # Générer une nouvelle paire de clés
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/airquality_server_key

   # Vérifier les permissions
   chmod 600 ~/.ssh/airquality_server_key
   chmod 644 ~/.ssh/airquality_server_key.pub
   ```

2. **Configuration du serveur** :
   ```bash
   # Copier la clé publique sur le serveur
   ssh-copy-id -i ~/.ssh/airquality_server_key.pub user@192.168.1.134

   # Vérifier les permissions sur le serveur
   ssh user@192.168.1.134 "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
   ```

### 2. Configuration du client SSH

1. **Configuration du fichier ~/.ssh/config** :
   ```bash
   # Créer ou modifier la configuration
   cat > ~/.ssh/config << EOF
   Host airquality
       HostName 192.168.1.134
       User user
       IdentityFile ~/.ssh/airquality_server_key
       StrictHostKeyChecking no
   EOF

   # Tester la connexion
   ssh airquality
   ```

2. **Vérification de la connexion** :
   ```bash
   # Test de connexion
   ssh -v airquality

   # Vérification des logs
   tail -f /var/log/auth.log
   ```

### 3. Dépannage SSH

1. **Erreurs courantes** :
   - "Permission denied (publickey)" : Vérifier les permissions des clés
   - "Identity file not accessible" : Vérifier le chemin de la clé
   - "Connection refused" : Vérifier que le service SSH est actif

2. **Vérification du serveur SSH** :
   ```bash
   # Statut du service
   sudo systemctl status sshd

   # Configuration
   sudo cat /etc/ssh/sshd_config | grep -i "PubkeyAuthentication"

   # Logs
   sudo tail -f /var/log/auth.log
   ```

3. **Réinitialisation des permissions** :
   ```bash
   # Sur le client
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/airquality_server_key
   chmod 644 ~/.ssh/airquality_server_key.pub

   # Sur le serveur
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

## Configuration SSH Freebox

### 1. Génération de la clé SSH

1. **Génération de la paire de clés** :
   ```bash
   # Générer une nouvelle paire de clés
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/freebox_ultra_key

   # Vérifier les permissions
   chmod 600 ~/.ssh/freebox_ultra_key
   chmod 644 ~/.ssh/freebox_ultra_key.pub
   ```

2. **Configuration du client SSH** :
   ```bash
   # Configuration du fichier ~/.ssh/config
   cat > ~/.ssh/config << EOF
   Host freebox
       HostName 192.168.1.254
       User freebox
       IdentityFile ~/.ssh/freebox_ultra_key
       StrictHostKeyChecking no
   EOF
   ```

### 2. Configuration de la Freebox

1. **Interface web Freebox** :
   - Connectez-vous à mafreebox.freebox.fr
   - Allez dans "Paramètres" > "Système" > "Accès SSH"
   - Activez l'accès SSH si ce n'est pas déjà fait
   - Copiez la clé publique :
     ```bash
     cat ~/.ssh/freebox_ultra_key.pub
     ```
   - Collez la clé dans le champ approprié
   - Sauvegardez les modifications

2. **Test de la connexion** :
   ```bash
   # Test de connexion
   ssh -v freebox

   # Vérification des logs
   tail -f /var/log/auth.log
   ```

### 3. Dépannage Freebox SSH

1. **Erreurs courantes** :
   - "Permission denied" : Vérifier l'activation SSH dans l'interface Freebox
   - "Connection refused" : Vérifier que le service SSH est activé sur la Freebox
   - "Host key verification failed" : Vérifier la configuration StrictHostKeyChecking

2. **Vérification de la configuration** :
   ```bash
   # Vérifier la configuration SSH
   ssh -T freebox

   # Vérifier les permissions
   ls -l ~/.ssh/freebox_ultra_key*
   ```

3. **Réinitialisation** :
   ```bash
   # Supprimer la clé existante
   rm ~/.ssh/freebox_ultra_key*

   # Régénérer la clé
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/freebox_ultra_key

   # Reconfigurer la Freebox
   # (Suivre les étapes de configuration de l'interface web)
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

2. **Permissions requises pour DynDNS** :
   - GET /domain/zone/*
   - PUT /domain/zone/*
   - POST /domain/zone/*
   - DELETE /domain/zone/*

### 2. Création d'une nouvelle application

 lien pour créer un token

https://www.ovh.com/auth/api/createToken

lien pour obtenir la liste des endpoint OVH

https://github.com/ovh/python-ovh#2-configure-your-application

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
               {'method': 'DELETE', 'path': '/domain/zone/*'}
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

### 3. Mise à jour des variables d'environnement

1. **Configuration du fichier .env** :
   ```bash
   # Mettre à jour les variables OVH
   OVH_APPLICATION_KEY=votre_nouvelle_application_key
   OVH_APPLICATION_SECRET=votre_nouvelle_application_secret
   OVH_CONSUMER_KEY=votre_nouveau_consumer_key
   ```

2. **Vérification de la configuration** :
   ```bash
   # Tester la nouvelle configuration
   python test_ovh_api.py
   ```

### 4. Dépannage des permissions

1. **Erreurs courantes** :
   - "This call has not been granted" : Permissions manquantes
   - "Invalid signature" : Clés API incorrectes
   - "Resource not found" : Mauvais endpoint

2. **Solutions** :
   - Vérifier les permissions dans l'interface OVH
   - Régénérer les clés API
   - Mettre à jour le Consumer Key

3. **Vérification des logs** :
   ```bash
   # Vérifier les logs d'erreur
   tail -f /var/log/ovh_dns.log
   ```

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

### 4. Bonnes pratiques

1. **Identification des tokens inutiles** :
   - Tokens expirés
   - Tokens avec des droits insuffisants
   - Tokens non utilisés depuis longtemps
   - Doublons (mêmes droits, même application)

2. **Vérification avant suppression** :
   ```bash
   # Vérifier l'utilisation du token
   curl -X GET "https://eu.api.ovh.com/1.0/auth/credential/{credentialId}/logs" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

3. **Création d'un nouveau token** :
   - Garder l'ancien token actif pendant la transition
   - Tester le nouveau token
   - Supprimer l'ancien token une fois la migration validée

### 5. Script de nettoyage

```bash
#!/bin/bash

# Configuration
OVH_APPLICATION_KEY="votre_application_key"
OVH_APPLICATION_SECRET="votre_application_secret"
OVH_CONSUMER_KEY="votre_consumer_key"

# Récupération de la liste des tokens
TOKENS=$(curl -s -X GET "https://eu.api.ovh.com/1.0/auth/credential" \
    -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
    -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY")

# Analyse de chaque token
for TOKEN_ID in $(echo $TOKENS | jq -r '.[]'); do
    # Récupération des détails du token
    TOKEN_DETAILS=$(curl -s -X GET "https://eu.api.ovh.com/1.0/auth/credential/$TOKEN_ID" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY")

    # Vérification des droits
    RIGHTS=$(echo $TOKEN_DETAILS | jq -r '.rules[] | .path')

    # Affichage des informations
    echo "Token ID: $TOKEN_ID"
    echo "Droits: $RIGHTS"
    echo "-------------------"
done
```

### 6. Dépannage

1. **Erreurs courantes** :
   - "Token not found" : Vérifier l'ID du token
   - "Permission denied" : Vérifier les droits du token utilisé
   - "Invalid signature" : Vérifier les clés API

2. **Vérification des logs** :
   ```bash
   # Logs des actions sur les tokens
   curl -X GET "https://eu.api.ovh.com/1.0/auth/log" \
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

### 3. Bonnes pratiques

1. **DynDNS (IP dynamique)** :
   - Utiliser TTL = 60 secondes
   - Exemples :
     - airquality.iaproject.fr
     - sensors.iaproject.fr
     - dyn.iaproject.fr

2. **Hébergement statique** :
   - Utiliser TTL = 0 ou 3600
   - Exemples :
     - www.iaproject.fr
     - blog.iaproject.fr
     - api.iaproject.fr

3. **Vérification des TTL** :
   ```bash
   # Liste tous les enregistrements avec leurs TTL
   curl -X GET "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/record" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```

### 4. Optimisation des TTL

1. **Pour les sous-domaines DynDNS** :
   - TTL court (60 secondes) pour :
     - Mise à jour rapide de l'IP
     - Réactivité aux changements
     - Minimisation des erreurs DNS

2. **Pour les sous-domaines statiques** :
   - TTL long (0 ou 3600) pour :
     - Réduction de la charge DNS
     - Meilleure performance
     - Cache plus efficace

3. **Mise à jour groupée** :
   ```bash
   # Script pour harmoniser les TTL
   for RECORD_ID in $(curl -s -X GET "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/record" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" | jq -r '.[]'); do

     # Vérifier si c'est un sous-domaine DynDNS
     if [[ $RECORD_ID == *"dyn"* ]]; then
       TTL=60
     else
       TTL=0
     fi

     # Mettre à jour le TTL
     curl -X PUT "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/record/$RECORD_ID" \
          -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
          -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"ttl\": $TTL}"
   done

   # Rafraîchir la zone
   curl -X POST "https://eu.api.ovh.com/1.0/domain/zone/iaproject.fr/refresh" \
        -H "X-Ovh-Application: $OVH_APPLICATION_KEY" \
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY"
   ```