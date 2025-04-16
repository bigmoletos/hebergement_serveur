#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de test pour la configuration DNS et l'API OVH.

Ce script effectue une série de tests pour vérifier :
- La configuration des variables d'environnement
- La connexion à l'API OVH
- La récupération des enregistrements DNS
- La mise à jour des enregistrements

Auteur: Franck DESMEDT
Date: 2024
Version: 1.0
"""

import sys
import logging
import requests
from logger import setup_logger, mask_sensitive
from config import config

# Configuration du logger
logger = setup_logger(__name__)


def print_required_rights():
    """
    Affiche les droits nécessaires pour l'API OVH et les instructions pour les obtenir.
    """
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


def test_dns_update():
    """
    Test la configuration DNS et la connexion à l'API OVH.

    Cette fonction effectue les tests suivants :
    1. Vérifie la présence des variables de configuration requises
    2. Teste la récupération de l'IP publique
    3. Teste la connexion à l'API OVH
    4. Teste la récupération des enregistrements DNS

    Returns:
        bool: True si tous les tests réussissent, False sinon

    Raises:
        Exception: En cas d'erreur lors des tests
    """
    try:
        # Liste des variables requises
        required_vars = [
            'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
            'OVH_CONSUMER_KEY', 'OVH_DNS_ZONE', 'OVH_DNS_SUBDOMAIN',
            'OVH_DNS_RECORD_ID'
        ]

        # Vérification des variables requises
        if not config.check_required_vars(required_vars):
            return False

        # Affichage des variables chargées (avec masquage des valeurs sensibles)
        for var in required_vars:
            value = config.get(var)
            if var in [
                    'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
                    'OVH_CONSUMER_KEY'
            ]:
                logger.info(
                    f"Variable {var} chargée : {mask_sensitive(value)}")
            else:
                logger.info(f"Variable {var} chargée : {value}")

        # Test de la récupération de l'IP publique
        logger.info("Test de la récupération de l'IP publique...")
        response = requests.get('https://api.ipify.org')
        ip = response.text
        logger.info(f"IP publique actuelle : {mask_sensitive(ip)}")

        # Test de la connexion à l'API OVH
        logger.info("Test de la connexion à l'API OVH...")
        client = config.get_ovh_client()

        # Test de la récupération des informations DNS
        zone = config.get_required('OVH_DNS_ZONE')
        record_id = config.get_required('OVH_DNS_RECORD_ID')

        try:
            logger.info(
                f"Test de lecture de l'enregistrement DNS {record_id}...")
            record = client.get(f'/domain/zone/{zone}/record/{record_id}')

            # Masquage des informations sensibles
            masked_record = record.copy()
            if 'target' in masked_record:
                masked_record['target'] = mask_sensitive(
                    masked_record['target'])
            logger.info(f"Enregistrement DNS actuel : {masked_record}")
            return True

        except Exception as e:
            logger.error(
                f"Erreur lors de la récupération de l'enregistrement DNS : {e}"
            )
            print_required_rights(
            )  # Affiche les droits nécessaires en cas d'erreur
            return False

    except Exception as e:
        logger.error(f"Erreur lors du test : {e}")
        return False


if __name__ == "__main__":
    """
    Point d'entrée principal du script.

    Exécute les tests DNS et affiche le résultat.
    """
    logger.info("Début du test DNS")
    if test_dns_update():
        logger.info("Test réussi")
    else:
        logger.error("Test échoué")
