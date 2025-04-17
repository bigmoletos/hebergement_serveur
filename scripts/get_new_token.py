#!/usr/bin/env python3
"""
Script pour générer un nouveau bearer token OVH avec les droits nécessaires pour la gestion DNS.

Ce script permet de :
1. Créer un nouveau token d'accès à l'API OVH
2. Définir les permissions spécifiques pour la gestion DNS
3. Générer une URL de validation
4. Fournir les instructions pour finaliser l'authentification

Prérequis:
    - Python 3.x
    - Package ovh: pip install ovh
    - Fichier de configuration avec les credentials OVH:
        - OVH_ENDPOINT
        - OVH_APPLICATION_KEY
        - OVH_APPLICATION_SECRET

Permissions requises:
    - GET /domain/zone/*/record : Lecture des enregistrements DNS
    - PUT /domain/zone/*/record/* : Modification des enregistrements DNS
    - POST /domain/zone/*/refresh : Rafraîchissement de la zone DNS
    - POST /domain/zone/*/record : Création d'enregistrements DNS
    - DELETE /domain/zone/*/record/* : Suppression d'enregistrements DNS
    - GET /domain/zone/* : Lecture des informations de zone

Utilisation:
    python3 get_new_token.py

Retour:
    - Consumer Key: Clé d'accès à l'API
    - Validation URL: URL pour valider les permissions
"""
import json
import ovh
from logger import setup_logger
from config import config

# Configuration du logger pour le suivi des opérations
logger = setup_logger(__name__)


def get_new_token():
    """
    Génère un nouveau token OVH avec les droits nécessaires pour la gestion DNS.

    Cette fonction:
    1. Initialise le client OVH avec les credentials de base
    2. Définit les règles d'accès nécessaires
    3. Génère un nouveau token
    4. Affiche les informations et instructions

    Returns:
        dict: Dictionnaire contenant:
            - consumerKey: La nouvelle clé de consommateur
            - validationUrl: URL pour valider les permissions
            - state: État de la demande
    """
    try:
        # Initialisation du client OVH avec les credentials de base
        client = ovh.Client(
            endpoint=config.get_required('OVH_ENDPOINT'),
            application_key=config.get_required('OVH_APPLICATION_KEY'),
            application_secret=config.get_required('OVH_APPLICATION_SECRET'))

        # Définition des droits nécessaires pour la gestion DNS complète
        access_rules = [
            # Lecture des informations de zone
            {
                'method': 'GET',
                'path': '/domain/zone/*'
            },
            # Gestion des enregistrements DNS
            {
                'method': 'GET',
                'path': '/domain/zone/*/record'
            },
            {
                'method': 'POST',
                'path': '/domain/zone/*/record'
            },
            {
                'method': 'PUT',
                'path': '/domain/zone/*/record/*'
            },
            {
                'method': 'DELETE',
                'path': '/domain/zone/*/record/*'
            },
            # Rafraîchissement de la zone
            {
                'method': 'POST',
                'path': '/domain/zone/*/refresh'
            }
        ]

        # Création du nouveau token avec les règles d'accès définies
        credentials = client.request_consumerkey(access_rules)

        # Affichage des informations importantes
        logger.info("\nNouveau token créé avec succès !")
        logger.info("Voici vos nouvelles informations :")
        logger.info(f"Consumer Key: {credentials['consumerKey']}")
        logger.info(f"Validation URL: {credentials['validationUrl']}")

        # Instructions détaillées pour l'utilisateur
        logger.info("\nInstructions pour finaliser l'authentification :")
        logger.info("1. Visitez l'URL de validation ci-dessus")
        logger.info("2. Connectez-vous avec votre compte OVH")
        logger.info("3. Acceptez les droits demandés")
        logger.info(
            "4. Mettez à jour votre fichier .env avec la nouvelle Consumer Key"
        )
        logger.info("   Exemple: OVH_CONSUMER_KEY=votre_nouvelle_consumer_key")

        return credentials

    except Exception as e:
        # Gestion des erreurs avec logging approprié
        logger.error(f"Erreur lors de la création du token : {str(e)}")
        return None


if __name__ == "__main__":
    # Point d'entrée du script
    get_new_token()
