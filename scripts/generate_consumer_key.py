#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour générer un nouveau consumer_key OVH avec les permissions nécessaires.

Ce script utilise l'API OVH pour créer un nouveau consumer_key avec les
permissions requises pour gérer les zones DNS.
"""

import requests
import json


def generate_consumer_key():
    """
    Génère un nouveau consumer_key avec les permissions nécessaires.
    """
    endpoint = "https://eu.api.ovh.com/1.0/auth/credential"

    # Application OVH existante
    application_key = "6f1ea4004ed10b98"
    domain = "airquality.iaproject.fr"

    # Définition des accès requis
    access_rules = [{
        "method": "GET",
        "path": f"/domain/zone/{domain}/record"
    }, {
        "method": "POST",
        "path": f"/domain/zone/{domain}/record"
    }, {
        "method": "PUT",
        "path": f"/domain/zone/{domain}/record/*"
    }, {
        "method": "DELETE",
        "path": f"/domain/zone/{domain}/record/*"
    }, {
        "method": "POST",
        "path": f"/domain/zone/{domain}/refresh"
    }]

    # Données de la requête
    payload = {
        "accessRules": access_rules,
        "redirection": "https://eu.api.ovh.com/console/"
    }

    # Headers
    headers = {
        "X-Ovh-Application": application_key,
        "Content-Type": "application/json"
    }

    try:
        print("Envoi de la requête à l'API OVH...")
        response = requests.post(endpoint,
                                 headers=headers,
                                 data=json.dumps(payload))

        if response.status_code != 200:
            print(f"Erreur HTTP {response.status_code}")
            print(f"Réponse : {response.text}")
            return

        result = response.json()

        print("\nInstructions pour valider le consumer_key :")
        print("----------------------------------------")
        print(f"1. Visitez cette URL pour valider : {result['validationUrl']}")
        print(f"2. Votre nouveau consumer_key : {result['consumerKey']}")
        print(f"3. État de validation : {result.get('state', 'inconnu')}")
        print("\nPermissions demandées :")
        for rule in access_rules:
            print(f"- {rule['method']} {rule['path']}")
        print(
            "\nUne fois validé, mettez à jour la variable OVH_CONSUMER_KEY dans votre .env"
        )

    except Exception as e:
        print(f"Erreur lors de la génération du consumer_key : {str(e)}")


if __name__ == "__main__":
    generate_consumer_key()
