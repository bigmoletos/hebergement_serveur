# Guide de Configuration DynDNS avec l'API OVH

Ce guide détaille les étapes pour configurer et tester un service DynDNS en utilisant l'API OVH.

## Table des matières
1. [Prérequis](#prérequis)
2. [Création des clés API OVH](#création-des-clés-api-ovh)
3. [Configuration des enregistrements DNS](#configuration-des-enregistrements-dns)
4. [Test de l'API](#test-de-lapi)
5. [Dépannage](#dépannage)

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
   - Authentifiez-vous avec vos clés API
   - Utilisez l'endpoint : `/domain/zone/{zoneName}/record`

3. Création d'un enregistrement A :
   ```bash
   POST /domain/zone/{zoneName}/record
   {
     "fieldType": "A",
     "subDomain": "votre-sous-domaine",
     "target": "votre-ip",
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