#!/usr/bin/env python3

import sys
import os
import logging
from dotenv import load_dotenv
from logger import setup_logger, mask_sensitive, check_required_vars

# Configuration du logger
logger = setup_logger(__name__)


def update_dns_record():
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

        # Récupération de l'IP publique
        import requests
        response = requests.get('https://api.ipify.org')
        new_ip = response.text
        logger.info(f"Nouvelle IP publique : {mask_sensitive(new_ip)}")

        # Connexion à l'API OVH
        import ovh
        client = ovh.Client(
            endpoint='ovh-eu',
            application_key=os.environ['OVH_APPLICATION_KEY'],
            application_secret=os.environ['OVH_APPLICATION_SECRET'],
            consumer_key=os.environ['OVH_CONSUMER_KEY'])

        # Mise à jour de l'enregistrement DNS
        zone = os.environ['OVH_DNS_ZONE']
        record_id = os.environ['OVH_DNS_RECORD_ID']
        subdomain = os.environ['OVH_DNS_SUBDOMAIN']

        try:
            # Récupération de l'enregistrement actuel
            record = client.get(f'/domain/zone/{zone}/record/{record_id}')
            current_ip = record['target']

            if current_ip != new_ip:
                logger.info(
                    f"Mise à jour nécessaire : IP actuelle {mask_sensitive(current_ip)} -> nouvelle IP {mask_sensitive(new_ip)}"
                )

                # Mise à jour de l'enregistrement
                client.put(f'/domain/zone/{zone}/record/{record_id}',
                           target=new_ip,
                           subDomain=subdomain,
                           ttl=60)

                # Déclenchement de la mise à jour de la zone
                client.post(f'/domain/zone/{zone}/refresh')
                logger.info("Mise à jour DNS effectuée avec succès")
            else:
                logger.info("Aucune mise à jour nécessaire : IP inchangée")

            return True
        except Exception as e:
            logger.error(f"Erreur lors de la mise à jour DNS : {e}")
            return False

    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour : {e}")
        return False


if __name__ == "__main__":
    logger.info("Début de la mise à jour DNS")
    if update_dns_record():
        logger.info("Mise à jour réussie")
    else:
        logger.error("Mise à jour échouée")
