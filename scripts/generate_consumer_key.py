#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour générer un nouveau consumer_key OVH avec les permissions nécessaires.

Ce script utilise l'API OVH pour créer un nouveau consumer_key avec les
permissions requises pour gérer les zones DNS.
"""

import ovh
import json
from logger import setup_logger
from config import config

# Configuration du logger
logger = setup_logger(__name__)


def generate_consumer_key():
    """
    Génère une nouvelle clé de consommateur (Consumer Key) avec les droits nécessaires.
    """
    try:
        # Création du client
        client = ovh.Client(
            endpoint='ovh-eu',
            application_key=config.get_required('OVH_APPLICATION_KEY'),
            application_secret=config.get_required('OVH_APPLICATION_SECRET'))

        # Définition des droits d'accès nécessaires
        access_rules = [{
            'method': 'GET',
            'path': '/domain/zone/*/record/*'
        }, {
            'method': 'PUT',
            'path': '/domain/zone/*/record/*'
        }, {
            'method': 'POST',
            'path': '/domain/zone/*/refresh'
        }, {
            'method': 'GET',
            'path': '/domain/zone/*/record'
        }, {
            'method': 'GET',
            'path': '/domain/zone/*/dynHost/record/*'
        }, {
            'method': 'PUT',
            'path': '/domain/zone/*/dynHost/record/*'
        }]

        # Demande de validation
        validation = client.request_consumerkey(access_rules)

        # Affichage des informations
        logger.info("\nNouvelle Consumer Key générée :")
        logger.info("-" * 50)
        logger.info(f"Consumer Key : {validation['consumerKey']}")
        logger.info("\nValidation requise :")
        logger.info("-" * 50)
        logger.info(
            f"1. Visitez cette URL pour valider : {validation['validationUrl']}"
        )
        logger.info("2. Cliquez sur 'Oui, je l'autorise'")
        logger.info(
            "3. Mettez à jour votre fichier .env avec la nouvelle Consumer Key"
        )

        # Sauvegarde des informations dans un fichier
        with open('ovh_credentials.json', 'w') as f:
            json.dump(
                {
                    'consumerKey': validation['consumerKey'],
                    'validationUrl': validation['validationUrl']
                },
                f,
                indent=2)
            logger.info(
                "\nLes informations ont été sauvegardées dans ovh_credentials.json"
            )

        return validation['consumerKey']

    except Exception as e:
        logger.error(
            f"Erreur lors de la génération de la Consumer Key : {str(e)}")
        raise


if __name__ == "__main__":
    logger.info("Génération d'une nouvelle Consumer Key...")
    generate_consumer_key()
