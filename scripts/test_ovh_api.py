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
import os
from dotenv import load_dotenv
from pathlib import Path
from logger import setup_logger, mask_sensitive, check_required_vars

# Configuration du logger
logger = setup_logger(__name__)


def load_env_variables(env_path: Path) -> tuple:
    """
    Charge les variables d'environnement depuis le fichier .env.

    Args:
        env_path (Path): Chemin vers le fichier .env

    Returns:
        tuple: (application_key, application_secret, consumer_key)
    """
    logger.info(f"Recherche du fichier .env dans : {env_path}")
    load_dotenv(dotenv_path=env_path)

    # Vérification des variables requises
    required_vars = [
        'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET', 'OVH_CONSUMER_KEY'
    ]
    check_required_vars(required_vars)

    # Récupération des variables
    ak = os.getenv('OVH_APPLICATION_KEY')
    as_ = os.getenv('OVH_APPLICATION_SECRET')
    ck = os.getenv('OVH_CONSUMER_KEY')

    # Masquage des valeurs sensibles dans les logs
    logger.info(f"Application Key: {mask_sensitive(ak)}")
    logger.info(f"Application Secret: {mask_sensitive(as_)}")
    logger.info(f"Consumer Key: {mask_sensitive(ck)}")

    return (ak, as_, ck)


def generate_ovh_signature(method: str, url: str, body: str,
                           application_secret: str, consumer_key: str,
                           timestamp: str) -> str:
    """
    Génère la signature pour l'authentification OVH selon la documentation officielle.

    Args:
        method (str): Méthode HTTP (GET, POST, PUT, DELETE)
        url (str): URL complète de l'endpoint
        body (str): Corps de la requête (vide pour GET)
        application_secret (str): Secret d'application OVH
        consumer_key (str): Clé du consommateur
        timestamp (str): Timestamp actuel

    Returns:
        str: Signature générée au format "$1$[signature_hex]"
    """
    to_sign = f"{application_secret}+{consumer_key}+{method}+{url}+{body}+{timestamp}"
    signature = "$1$" + hashlib.sha1(to_sign.encode('utf-8')).hexdigest()
    logger.debug(f"Chaîne à signer : {to_sign}")
    return signature


def print_debug_info(timestamp: str, to_sign: str, signature: str,
                     application_key: str, consumer_key: str,
                     url: str) -> None:
    """
    Affiche les informations de débogage et les instructions.

    Args:
        timestamp (str): Timestamp utilisé pour la signature
        to_sign (str): Chaîne utilisée pour générer la signature
        signature (str): Signature générée
        application_key (str): Clé d'application
        consumer_key (str): Clé du consommateur
        url (str): URL de l'endpoint
    """
    base_url = "https://eu.api.ovh.com/v1"
    full_url = f"{base_url}{url}"

    logger.info("\nInformations de débogage:")
    logger.info("------------------------")
    logger.info(f"Timestamp: {timestamp}")
    logger.info(f"Application Key: {mask_sensitive(application_key)}")
    logger.info(f"Consumer Key: {mask_sensitive(consumer_key)}")
    logger.info(f"URL: {full_url}")
    logger.info(f"Signature générée: {mask_sensitive(signature)}")

    print("\nHeaders à utiliser dans les requêtes:")
    print("--------------------------------")
    print("Content-Type: application/json")
    print(f"X-Ovh-Application: {application_key}")
    print(f"X-Ovh-Consumer: {consumer_key}")
    print(f"X-Ovh-Timestamp: {timestamp}")
    print(f"X-Ovh-Signature: {signature}")


def main():
    """
    Fonction principale qui orchestre la génération des headers d'authentification OVH.
    """
    try:
        # Chemin vers le fichier .env
        env_path = Path(__file__).parent.parent / '.env'

        # Charger les variables d'environnement
        application_key, application_secret, consumer_key = load_env_variables(
            env_path)

        # Paramètres de la requête
        method = 'GET'
        base_url = "https://eu.api.ovh.com/v1"
        endpoint = '/domain/zone/iaproject.fr/record'
        full_url = f"{base_url}{endpoint}"
        timestamp = str(int(time.time()))
        body = ""

        # Génération de la signature
        signature = generate_ovh_signature(
            method=method,
            url=full_url,
            body=body,
            application_secret=application_secret,
            consumer_key=consumer_key,
            timestamp=timestamp)

        # Affichage des informations pour les requêtes
        print_debug_info(
            timestamp=timestamp,
            to_sign=
            f"{application_secret}+{consumer_key}+{method}+{full_url}+{body}+{timestamp}",
            signature=signature,
            application_key=application_key,
            consumer_key=consumer_key,
            url=endpoint)

    except Exception as e:
        logger.error(f"Une erreur est survenue : {str(e)}")
        raise


if __name__ == "__main__":
    main()
