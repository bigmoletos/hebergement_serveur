#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de mise à jour DNS pour OVH
Ce script met à jour automatiquement les enregistrements DNS
pour les sous-domaines configurés.
"""

import os
import sys
import logging
import socket
import requests

# Configuration du logger
logger = logging.getLogger('ovh_dns')
logger.setLevel(logging.INFO)

# Création du handler pour les logs
handler = logging.FileHandler('/var/log/ovh_dns.log')
handler.setLevel(logging.INFO)

# Format des logs
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


def get_public_ip():
    try:
        # Utilisation de api.ipify.org pour obtenir l'IP publique
        response = requests.get('https://api.ipify.org')
        return response.text
    except Exception as e:
        logger.error(
            f"Erreur lors de la récupération de l'IP publique: {str(e)}")
        return None


def update_dns_record():
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
    logger.info("Début de la mise à jour DNS")
    if update_dns_record():
        logger.info("Mise à jour DNS réussie")
    else:
        logger.error("Échec de la mise à jour DNS")
