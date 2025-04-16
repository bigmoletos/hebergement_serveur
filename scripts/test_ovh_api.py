#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de test pour l'API OVH.

Ce script génère les headers d'authentification nécessaires pour effectuer
des requêtes à l'API OVH. Il utilise la méthode de signature officielle
d'OVH pour authentifier les requêtes.

Auteur: Franck DESMEDT
Date: 2024
Version: 1.1
"""

import hashlib
import time
from logger import setup_logger, mask_sensitive
from config import config

# Configuration du logger
logger = setup_logger(__name__)


def print_required_rights():
    """Affiche les droits nécessaires pour l'API OVH"""
    logger.info("\nDroits nécessaires pour l'API OVH:")
    logger.info("--------------------------------")
    logger.info("GET /domain/zone/*/record")
    logger.info("PUT /domain/zone/*/record/*")
    logger.info("POST /domain/zone/*/refresh")
    logger.info("\nPour obtenir ces droits:")
    logger.info("1. Allez sur https://api.ovh.com/createToken/")
    logger.info("2. Connectez-vous avec votre compte OVH")
    logger.info("3. Sélectionnez les droits suivants:")
    logger.info("   - GET /domain/zone/*/record")
    logger.info("   - PUT /domain/zone/*/record/*")
    logger.info("   - POST /domain/zone/*/refresh")
    logger.info("4. Copiez la nouvelle clé de consommateur (Consumer Key)")
    logger.info("5. Mettez à jour votre fichier .env avec la nouvelle clé")


def generate_ovh_signature(method: str, url: str, body: str,
                           timestamp: str) -> str:
    """
    Génère la signature pour l'authentification OVH selon la documentation officielle.

    Args:
        method (str): Méthode HTTP (GET, POST, PUT, DELETE)
        url (str): URL complète de l'endpoint
        body (str): Corps de la requête (vide pour GET)
        timestamp (str): Timestamp actuel

    Returns:
        str: Signature générée au format "$1$[signature_hex]"
    """
    application_secret = config.get_required('OVH_APPLICATION_SECRET')
    consumer_key = config.get_required('OVH_CONSUMER_KEY')

    to_sign = f"{application_secret}+{consumer_key}+{method}+{url}+{body}+{timestamp}"
    signature = "$1$" + hashlib.sha1(to_sign.encode('utf-8')).hexdigest()
    logger.debug(f"Chaîne à signer : {to_sign}")
    return signature


def print_debug_info(timestamp: str, to_sign: str, signature: str,
                     url: str) -> None:
    """
    Affiche les informations de débogage et les instructions.

    Args:
        timestamp (str): Timestamp utilisé pour la signature
        to_sign (str): Chaîne utilisée pour générer la signature
        signature (str): Signature générée
        url (str): URL de l'endpoint
    """
    base_url = "https://eu.api.ovh.com/v1"
    full_url = f"{base_url}{url}"

    logger.info("\nInformations de débogage:")
    logger.info("------------------------")
    logger.info(f"Timestamp: {timestamp}")
    logger.info(
        f"Application Key: {mask_sensitive(config.get_required('OVH_APPLICATION_KEY'))}"
    )
    logger.info(
        f"Consumer Key: {mask_sensitive(config.get_required('OVH_CONSUMER_KEY'))}"
    )
    logger.info(f"URL: {full_url}")
    logger.info(f"Signature générée: {mask_sensitive(signature)}")

    print("\nHeaders à utiliser dans les requêtes:")
    print("--------------------------------")
    print("Content-Type: application/json")
    print(f"X-Ovh-Application: {config.get_required('OVH_APPLICATION_KEY')}")
    print(f"X-Ovh-Consumer: {config.get_required('OVH_CONSUMER_KEY')}")
    print(f"X-Ovh-Timestamp: {timestamp}")
    print(f"X-Ovh-Signature: {signature}")


def main():
    """
    Fonction principale qui orchestre la génération des headers d'authentification OVH.
    """
    try:
        # Vérification des variables requises
        required_vars = [
            'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET', 'OVH_CONSUMER_KEY'
        ]
        if not config.check_required_vars(required_vars):
            return

        # Affichage des droits nécessaires
        print_required_rights()

        # Paramètres de la requête
        method = 'GET'
        base_url = "https://eu.api.ovh.com/v1"
        endpoint = f'/domain/zone/{config.get_required("OVH_DNS_ZONE")}/record'
        full_url = f"{base_url}{endpoint}"
        timestamp = str(int(time.time()))
        body = ""

        # Génération de la signature
        signature = generate_ovh_signature(method=method,
                                           url=full_url,
                                           body=body,
                                           timestamp=timestamp)

        # Affichage des informations pour les requêtes
        print_debug_info(
            timestamp=timestamp,
            to_sign=
            f"{config.get_required('OVH_APPLICATION_SECRET')}+{config.get_required('OVH_CONSUMER_KEY')}+{method}+{full_url}+{body}+{timestamp}",
            signature=signature,
            url=endpoint)

    except Exception as e:
        logger.error(f"Une erreur est survenue : {str(e)}")
        raise

if __name__ == "__main__":
    main()
