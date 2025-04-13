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
import ovh
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S')
logger = logging.getLogger(__name__)


def load_env_vars():
    """Charge les variables d'environnement depuis le fichier .env"""
    env_file = "/hebergement_serveur/.env"
    env_vars = {}

    try:
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip().strip("'")
    except Exception as e:
        logger.error(f"Erreur lors du chargement du fichier .env: {e}")
        sys.exit(1)

    return env_vars


def update_dns():
    """Met à jour les enregistrements DNS"""
    try:
        # Chargement des variables d'environnement
        env_vars = load_env_vars()

        # Vérification des variables requises
        required_vars = [
            'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
            'OVH_CONSUMER_KEY', 'OVH_DNS_ZONE', 'OVH_DNS_SUBDOMAIN',
            'OVH_DNS_RECORD_ID'
        ]

        for var in required_vars:
            if var not in env_vars:
                logger.error(f"Variable manquante: {var}")
                sys.exit(1)

        # Configuration du client OVH
        client = ovh.Client(
            endpoint=env_vars.get('OVH_API_ENDPOINT', 'ovh-eu'),
            application_key=env_vars['OVH_APPLICATION_KEY'],
            application_secret=env_vars['OVH_APPLICATION_SECRET'],
            consumer_key=env_vars['OVH_CONSUMER_KEY'])

        # Récupération de l'adresse IP actuelle
        ip_address = env_vars.get('IP_ADDRESS')
        if not ip_address:
            logger.error("Adresse IP non définie")
            sys.exit(1)

        # Mise à jour de l'enregistrement DNS principal
        try:
            client.put(
                f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/record/{env_vars["OVH_DNS_RECORD_ID"]}',
                subDomain=env_vars['OVH_DNS_SUBDOMAIN'],
                target=ip_address,
                ttl=60)
            logger.info(
                f"Mise à jour DNS réussie pour {env_vars['OVH_DNS_SUBDOMAIN']}.{env_vars['OVH_DNS_ZONE']}"
            )
        except Exception as e:
            logger.error(f"Erreur lors de la mise à jour DNS: {e}")
            sys.exit(1)

        # Mise à jour des sous-domaines supplémentaires
        additional_subdomains = env_vars.get('DYNDNS_ADDITIONAL_SUBDOMAINS',
                                             '').split(',')
        for subdomain in additional_subdomains:
            subdomain = subdomain.strip()
            if subdomain:
                try:
                    # Recherche de l'ID de l'enregistrement pour le sous-domaine
                    records = client.get(
                        f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/record',
                        fieldType='A',
                        subDomain=subdomain)

                    if records:
                        record_id = records[0]
                        client.put(
                            f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/record/{record_id}',
                            subDomain=subdomain,
                            target=ip_address,
                            ttl=60)
                        logger.info(
                            f"Mise à jour DNS réussie pour {subdomain}.{env_vars['OVH_DNS_ZONE']}"
                        )
                    else:
                        # Création d'un nouvel enregistrement si nécessaire
                        client.post(
                            f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/record',
                            fieldType='A',
                            subDomain=subdomain,
                            target=ip_address,
                            ttl=60)
                        logger.info(
                            f"Création DNS réussie pour {subdomain}.{env_vars['OVH_DNS_ZONE']}"
                        )
                except Exception as e:
                    logger.error(
                        f"Erreur lors de la mise à jour DNS pour {subdomain}: {e}"
                    )

        # Rafraîchissement de la zone DNS
        try:
            client.post(f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/refresh')
            logger.info("Zone DNS rafraîchie avec succès")
        except Exception as e:
            logger.error(
                f"Erreur lors du rafraîchissement de la zone DNS: {e}")

    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour DNS: {e}")
        sys.exit(1)


if __name__ == "__main__":
    logger.info("Début de la mise à jour DNS")
    update_dns()
    logger.info("Mise à jour DNS terminée avec succès")
