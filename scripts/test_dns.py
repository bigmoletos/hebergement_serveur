#!/usr/bin/env python3

import sys
import os
import logging
from dotenv import load_dotenv
from logger import setup_logger, mask_sensitive, check_required_vars

# Configuration du logger
logger = setup_logger(__name__)


def test_dns_update():
    try:
        # Chargement des variables d'environnement
        load_dotenv('/hebergement_serveur/.env')

        # Vérification des variables requises
        required_vars = [
            'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
            'OVH_CONSUMER_KEY', 'OVH_DNS_ZONE', 'OVH_DNS_SUBDOMAIN',
            'OVH_DNS_RECORD_ID'
        ]
        check_required_vars(required_vars)

        # Test de la récupération de l'IP publique
        import requests
        response = requests.get('https://api.ipify.org')
        ip = response.text
        logger.info(f"IP publique actuelle : {mask_sensitive(ip)}")

        # Test de la connexion à l'API OVH
        import ovh
        client = ovh.Client(
            endpoint='ovh-eu',
            application_key=os.environ['OVH_APPLICATION_KEY'],
            application_secret=os.environ['OVH_APPLICATION_SECRET'],
            consumer_key=os.environ['OVH_CONSUMER_KEY'])

        # Test de la récupération des informations DNS
        zone = os.environ['OVH_DNS_ZONE']
        record_id = os.environ['OVH_DNS_RECORD_ID']

        try:
            record = client.get(f'/domain/zone/{zone}/record/{record_id}')
            # Masquage des informations sensibles dans l'enregistrement DNS
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
            return False

    except Exception as e:
        logger.error(f"Erreur lors du test : {e}")
        return False


if __name__ == "__main__":
    logger.info("Début du test DNS")
    if test_dns_update():
        logger.info("Test réussi")
    else:
        logger.error("Test échoué")
