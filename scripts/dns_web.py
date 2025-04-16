#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de mise à jour DNS pour OVH via une interface web.

Ce script fournit une interface web pour gérer les mises à jour DNS
dynamiques via l'API OVH. Il permet de :
- Afficher l'état actuel des enregistrements DNS
- Mettre à jour les enregistrements avec l'IP publique actuelle
- Rafraîchir la zone DNS

Auteur: Franck DESMEDT
Date: 2024
Version: 1.0
"""

import sys
import logging
import requests
from logger import setup_logger
from config import config

# Configuration du logger
logger = setup_logger(__name__)


def update_dns_record():
    """
    Met à jour l'enregistrement DNS avec l'IP publique actuelle.

    Cette fonction :
    1. Vérifie les variables de configuration requises
    2. Récupère l'IP publique actuelle
    3. Met à jour l'enregistrement DNS via l'API OVH
    4. Rafraîchit la zone DNS

    Returns:
        bool: True si la mise à jour a réussi, False sinon

    Raises:
        Exception: En cas d'erreur lors de la mise à jour
    """
    try:
        # Vérification des variables requises
        required_vars = [
            'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
            'OVH_CONSUMER_KEY', 'OVH_DNS_ZONE', 'OVH_DNS_SUBDOMAIN',
            'OVH_DNS_RECORD_ID', 'IP_FREEBOX'
        ]
        if not config.check_required_vars(required_vars):
            return False

        # Récupération de l'IP publique
        logger.info("Récupération de l'IP publique...")
        new_ip = config.get_required('IP_FREEBOX')
        logger.info(f"Nouvelle IP publique : {config.mask_sensitive(new_ip)}")

        # Connexion à l'API OVH
        logger.info("Connexion à l'API OVH...")
        client = config.get_ovh_client()

        # Mise à jour de l'enregistrement DNS
        zone = config.get_required('OVH_DNS_ZONE')
        record_id = config.get_required('OVH_DNS_RECORD_ID')
        subdomain = config.get_required('OVH_DNS_SUBDOMAIN')

        try:
            # Récupération de l'enregistrement actuel
            record = client.get(f'/domain/zone/{zone}/record/{record_id}')
            current_ip = record['target']

            if current_ip != new_ip:
                logger.info(
                    f"Mise à jour nécessaire : IP actuelle {config.mask_sensitive(current_ip)} -> nouvelle IP {config.mask_sensitive(new_ip)}"
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
    """
    Point d'entrée principal du script.

    Exécute la mise à jour DNS et affiche le résultat.
    """
    logger.info("Début de la mise à jour DNS")
    if update_dns_record():
        logger.info("Mise à jour réussie")
    else:
        logger.error("Mise à jour échouée")
