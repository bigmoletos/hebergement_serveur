#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de mise à jour DNS pour OVH
Ce script met à jour automatiquement les enregistrements DNS
pour les sous-domaines configurés.
"""

import os
import sys

# Ajout du répertoire scripts au PYTHONPATH
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(script_dir)

import ovh
from datetime import datetime
from logger import setup_logger, mask_sensitive, check_required_vars, log_exception

# Configuration du logger
logger = setup_logger('ovh_dns', '/var/log/ovh_dns.log')


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
        log_exception(logger, e, "Erreur lors du chargement du fichier .env")
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

        if not check_required_vars(required_vars, logger):
            sys.exit(1)

        # Configuration du client OVH
        logger.info("Configuration du client OVH...")
        client = ovh.Client(
            endpoint=env_vars.get('OVH_API_ENDPOINT', 'ovh-eu'),
            application_key=env_vars['OVH_APPLICATION_KEY'],
            application_secret=env_vars['OVH_APPLICATION_SECRET'],
            consumer_key=env_vars['OVH_CONSUMER_KEY'])
        logger.info("Client OVH configuré avec succès")

        # Récupération de l'adresse IP actuelle
        ip_address = env_vars.get('IP_ADDRESS')
        if not ip_address:
            logger.error("Adresse IP non définie")
            sys.exit(1)

        logger.info(f"Adresse IP à utiliser : {mask_sensitive(ip_address)}")

        # Mise à jour de l'enregistrement DNS principal
        try:
            logger.info("Mise à jour de l'enregistrement DNS principal...")
            client.put(
                f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/record/{env_vars["OVH_DNS_RECORD_ID"]}',
                subDomain=env_vars['OVH_DNS_SUBDOMAIN'],
                target=ip_address,
                ttl=60)
            logger.info(
                f"Mise à jour DNS réussie pour {env_vars['OVH_DNS_SUBDOMAIN']}.{env_vars['OVH_DNS_ZONE']}"
            )
        except Exception as e:
            log_exception(logger, e, "Erreur lors de la mise à jour DNS")
            sys.exit(1)

        # Mise à jour des sous-domaines supplémentaires
        additional_subdomains = env_vars.get('DYNDNS_ADDITIONAL_SUBDOMAINS',
                                             '').split(',')
        for subdomain in additional_subdomains:
            subdomain = subdomain.strip()
            if subdomain:
                try:
                    logger.info(f"Traitement du sous-domaine : {subdomain}")
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
                    log_exception(
                        logger, e,
                        f"Erreur lors de la mise à jour DNS pour {subdomain}")

        # Rafraîchissement de la zone DNS
        try:
            logger.info("Rafraîchissement de la zone DNS...")
            client.post(f'/domain/zone/{env_vars["OVH_DNS_ZONE"]}/refresh')
            logger.info("Zone DNS rafraîchie avec succès")
        except Exception as e:
            log_exception(logger, e,
                          "Erreur lors du rafraîchissement de la zone DNS")

    except Exception as e:
        log_exception(logger, e, "Erreur lors de la mise à jour DNS")
        sys.exit(1)

if __name__ == "__main__":
    logger.info("Début de la mise à jour DNS")
    update_dns()
    logger.info("Mise à jour DNS terminée avec succès")
