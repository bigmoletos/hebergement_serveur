#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de mise à jour DNS pour OVH.

Ce script met à jour automatiquement les enregistrements DNS
pour les sous-domaines configurés. Il :
- Récupère l'IP publique actuelle
- Met à jour les enregistrements DNS via l'API OVH
- Rafraîchit la zone DNS

Auteur: Franck DESMEDT
Date: 2024
Version: 1.0
"""

import os
import sys
import logging
import socket
import requests
from config import config
from logger import setup_logger

# Configuration du logger
logger = setup_logger('ovh_dns')
logger.setLevel(logging.INFO)

# Création du handler pour les logs
handler = logging.FileHandler('/var/log/ovh_dns.log')
handler.setLevel(logging.INFO)

# Format des logs
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


def get_public_ip():
    """
    Récupère l'IP publique actuelle du serveur.

    Utilise l'IP_FREEBOX définie dans les variables d'environnement.

    Returns:
        str: L'IP publique du serveur ou None en cas d'erreur

    Raises:
        Exception: En cas d'erreur lors de la récupération de l'IP
    """
    try:
        # Utilisation de l'IP_FREEBOX via config.py
        ip_freebox = config.get_required('IP_FREEBOX')
        if not ip_freebox:
            logger.error("Variable IP_FREEBOX non définie")
            return None
        return ip_freebox
    except Exception as e:
        logger.error(
            f"Erreur lors de la récupération de l'IP publique: {str(e)}")
        return None


def update_dns_record():
    """
    Met à jour l'enregistrement DNS avec l'IP publique actuelle.

    Cette fonction :
    1. Vérifie les variables d'environnement requises
    2. Récupère l'IP publique actuelle
    3. Met à jour l'enregistrement DNS via l'API OVH
    4. Rafraîchit la zone DNS

    Returns:
        bool: True si la mise à jour a réussi, False sinon

    Raises:
        Exception: En cas d'erreur lors de la mise à jour
    """
    try:
        # Vérification des variables d'environnement requises
        required_vars = [
            'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
            'OVH_CONSUMER_KEY', 'OVH_DNS_ZONE', 'OVH_DNS_SUBDOMAIN',
            'OVH_DNS_RECORD_ID'
        ]

        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            logger.error(
                f"Variables d'environnement manquantes: {', '.join(missing_vars)}"
            )
            return False

        # Configuration du client OVH
        logger.info("Configuration du client OVH...")
        client = ovh.Client(
            endpoint='ovh-eu',
            application_key=os.getenv('OVH_APPLICATION_KEY'),
            application_secret=os.getenv('OVH_APPLICATION_SECRET'),
            consumer_key=os.getenv('OVH_CONSUMER_KEY'))
        logger.info("Client OVH configuré avec succès")

        # Récupération de l'IP publique
        logger.info("Récupération de l'IP publique...")
        new_ip = get_public_ip()
        if not new_ip:
            logger.error("Impossible de récupérer l'IP publique")
            return False

        logger.info(f"Nouvelle IP publique: {new_ip[:5]}***")

        # Mise à jour de l'enregistrement DNS
        logger.info("Mise à jour de l'enregistrement DNS...")
        result = client.put(
            f'/domain/zone/{os.getenv("OVH_DNS_ZONE")}/record/{os.getenv("OVH_DNS_RECORD_ID")}',
            subDomain=os.getenv('OVH_DNS_SUBDOMAIN'),
            target=new_ip,
            ttl=60)

        logger.info("Enregistrement DNS mis à jour avec succès")
        return True

    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour DNS: {str(e)}")
        return False


if __name__ == "__main__":
    """
    Point d'entrée principal du script.

    Exécute la mise à jour DNS et affiche le résultat.
    """
    logger.info("Début de la mise à jour DNS")
    if update_dns_record():
        logger.info("Mise à jour DNS réussie")
    else:
        logger.error("Échec de la mise à jour DNS")
