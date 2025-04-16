"""Script de démonstration pour l'utilisation de l'API OVH.

Ce script illustre l'utilisation de l'API OVH pour :
1. Vérifier les permissions du token
2. Récupérer les informations de contact du domaine
3. Obtenir les détails d'authentification
4. Obtenir les informations de la zone DNS

Source: https://eu.api.ovh.com/console/?section=%2Fdomain&branch=v1#get-/domain/zone/-zoneName-

Prérequis:
    - Python 3.x
    - Package ovh: pip install ovh
    - Credentials OVH (Application Key, Secret, Consumer Key)
    - Permissions API nécessaires:
        - GET /domain/zone/*
        - GET /auth/*
        - GET /domain/contact
"""

import json
import ovh
import requests
from logger import setup_logger
from config import config
from ovh.exceptions import APIError

# Configuration du logger pour le suivi des opérations
logger = setup_logger(__name__)


def check_token_permissions(client):
    """Vérifie les permissions du token OVH.

    Args:
        client: Instance du client OVH

    Returns:
        dict: Informations sur les permissions du token
    """
    try:
        # Récupération des détails d'authentification
        result = client.get("/auth/details")
        logger.info("Permissions du token récupérées avec succès")

        # Affichage des permissions
        logger.info("\nPermissions du token:")
        logger.info(f"Application: {result.get('applicationName')}")
        logger.info(f"Description: {result.get('description')}")
        logger.info(f"Expiration: {result.get('expiration')}")

        # Affichage des règles d'accès
        logger.info("\nRègles d'accès:")
        for rule in result.get('rules', []):
            logger.info(f"- {rule.get('method')} {rule.get('path')}")

        return result
    except APIError as e:
        logger.error(
            f"Erreur lors de la vérification des permissions: {str(e)}")
        return None


# Initialisation du client OVH avec les credentials
try:
    client = ovh.Client(
        endpoint=config.get_required('OVH_ENDPOINT'),
        application_key=config.get_required('OVH_APPLICATION_KEY'),
        application_secret=config.get_required('OVH_APPLICATION_SECRET'),
        consumer_key=config.get_required('OVH_CONSUMER_KEY'),
    )
    logger.info("Client OVH initialisé avec succès")
except Exception as e:
    logger.error(f"Erreur lors de l'initialisation du client OVH: {str(e)}")
    exit(1)

# Requête HTTP pour récupérer les contacts du domaine
# Utilisation de l'endpoint /domain/contact
headers = {
    'accept':
    'application/json',
    'authorization':
    'Bearer eyJhbGciOiJFZERTQSIsImtpZCI6IkVGNThFMkUxMTFBODNCREFEMDE4OUUzMzZERTk3MDhFNjRDMDA4MDEiLCJraW5kIjoib2F1dGgyIiwidHlwIjoiSldUIn0.eyJBY2Nlc3NUb2tlbiI6ImI0ZDFhZjhkMDQyZmQ1MTlkYzQ3MzQwM2FmOWUyOWFkNmU2YjVmNGQ1MTViODU5NWY0ZDFjMzQ0MjczZmU2NWMiLCJpYXQiOjE3NDQ3MjQ3NzJ9.4l7JNawQN8tiWly7wHHr5S4JHhOe5mvqjSiKad0xYnm_4ikepRWMm8F5vQzTnfT8OV2vUILsTkFgEzFgB2vBCA'
}
# current credential
response_current_credential = requests.get('https://eu.api.ovh.com/v1/auth/currentCredential', headers=headers)
result_current_credential = response_current_credential.json()
logger.info("Current credential:")
logger.info(json.dumps(result_current_credential, indent=4))
# info authentication
response_authentication = requests.get(
    'https://eu.api.ovh.com/v1/auth/details', headers=headers)
result_authentication = response_authentication.json()
logger.info("Authentication:")
logger.info(json.dumps(result_authentication, indent=4))




# info contact
response_contact = requests.get('https://eu.api.ovh.com/v1/domain/contact',
                                headers=headers)
result_contact = response_contact.json()
# info record
response_id_record = requests.get('https://eu.api.ovh.com/v1/domain/zone/iaproject.fr/record?fieldType=A&subDomain=airquality',
                            headers=headers)
result_id_record = response_id_record.json()


# Affichage des informations de contact
print("\nStructure complète des données :")
print(json.dumps(result_contact, indent=4))

# Parcours et affichage détaillé de chaque contact
for i, contact in enumerate(result_contact):
    print(f"\nContact {i+1}:")
    print(json.dumps(contact, indent=4))

# Extraction de l'ID du premier contact administratif
if result_contact and len(result_contact) > 0:
    contact_id = result_contact[0]['id']
    logger.info(f"\nID contact admin: {contact_id}")

# Récupération du nom de zone depuis la configuration
zoneName = config.get_required('OVH_DNS_ZONE')
logger.info(f"Zone DNS: {zoneName}")
# Appels API pour obtenir différentes informations
# 1. Détails d'authentification
result_details = client.get("/auth/details")
# 2. Credentials actuels
result_auth = client.get("/auth/currentCredential")
# 3. Informations de la zone DNS
# result_zone = client.get(f"/domain/zone/{zoneName}")
# 4. Informations des enregistrements de la zone DNS
# result_id_record = client.get("/domain/zone/{zoneName}/record")

# Journalisation des résultats avec formatage JSON
logger.info("Détails d'authentification:")
logger.info(json.dumps(result_details, indent=4))
logger.info("Credentials actuels:")
logger.info(json.dumps(result_auth, indent=4))
logger.info("Informations de la zone DNS:")
# logger.info(json.dumps(result_zone, indent=4))
logger.info("Informations des enregistrements de la zone DNS \n id :")
logger.info(json.dumps(result_id_record, indent=4))

# Note: Le code commenté ci-dessous est l'exemple original de la documentation OVH
# Il est conservé à titre de référence
# '''
# First, install the latest release of Python wrapper: $ pip install ovh
# '''
# import json
# import ovh

# # Instantiate an OVH Client.
# # You can generate new credentials with full access to your account on
# # the token creation page (https://api.ovh.com/createToken/index.cgi?GET=/*&PUT=/*&POST=/*&DELETE=/*)
# client = ovh.Client(
# 	endpoint='ovh-eu',               # Endpoint of API OVH (List of available endpoints: https://github.com/ovh/python-ovh#2-configure-your-application)
# 	application_key='xxxxxxxxxx',    # Application Key
# 	application_secret='xxxxxxxxxx', # Application Secret
# 	consumer_key='xxxxxxxxxx',       # Consumer Key
# )

# result = client.get("/auth/details")

# # Pretty print
# print(json.dumps(result, indent=4))
