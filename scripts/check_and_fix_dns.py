#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour vérifier et supprimer définitivement l'enregistrement AAAA d'airquality
"""

import ovh
import os
import sys

# Ajout du répertoire scripts au PYTHONPATH
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(script_dir)

from config import config
from logger import setup_logger

# Configuration du logger
logger = setup_logger('fix_dns')


def check_and_fix_airquality_dns():
    """
    Vérifie et supprime l'enregistrement AAAA problématique
    """
    try:
        # Configuration du client OVH
        client = ovh.Client(
            endpoint='ovh-eu',
            application_key=config.get_required('OVH_APPLICATION_KEY'),
            application_secret=config.get_required('OVH_APPLICATION_SECRET'),
            consumer_key=config.get_required('OVH_CONSUMER_KEY'))

        dns_zone = config.get_required('OVH_DNS_ZONE')

        print(f"🔍 Vérification DNS pour airquality.iaproject.fr...")
        print("=" * 50)

        # Récupération des enregistrements airquality uniquement
        records = client.get(f'/domain/zone/{dns_zone}/record',
                             subDomain='airquality')

        airquality_records = []
        aaaa_to_delete = []

        for record_id in records:
            record_details = client.get(
                f'/domain/zone/{dns_zone}/record/{record_id}')

            print(f"📋 Enregistrement trouvé:")
            print(f"   ID: {record_id}")
            print(f"   Type: {record_details.get('fieldType')}")
            print(f"   Cible: {record_details.get('target')}")
            print(f"   TTL: {record_details.get('ttl')}")

            if record_details.get('fieldType') == 'AAAA':
                if '2001:41d0:301::23' in record_details.get('target', ''):
                    print(f"   ⚠️  PROBLÉMATIQUE - IPv6 vers OVH")
                    aaaa_to_delete.append(record_id)
                else:
                    print(f"   ✅ IPv6 OK")
            elif record_details.get('fieldType') == 'A':
                if record_details.get('target') == '91.173.110.4':
                    print(f"   ✅ IPv4 OK")
                else:
                    print(f"   ⚠️  IPv4 incorrect")

            print("-" * 30)

        # Suppression des enregistrements AAAA problématiques
        if aaaa_to_delete:
            print(
                f"\n🗑️  {len(aaaa_to_delete)} enregistrement(s) AAAA à supprimer..."
            )

            for record_id in aaaa_to_delete:
                try:
                    print(f"   Suppression de l'enregistrement {record_id}...")
                    client.delete(
                        f'/domain/zone/{dns_zone}/record/{record_id}')
                    print(f"   ✅ Supprimé avec succès")
                except Exception as e:
                    print(f"   ❌ Erreur: {str(e)}")
                    return False

            # Rafraîchissement obligatoire de la zone
            print(f"\n🔄 Rafraîchissement de la zone DNS...")
            try:
                client.post(f'/domain/zone/{dns_zone}/refresh')
                print(
                    f"✅ Zone rafraîchie - les changements seront actifs sous 5-10 minutes"
                )
            except Exception as e:
                print(f"❌ Erreur lors du rafraîchissement: {str(e)}")
                return False

            return True
        else:
            print(f"\n✅ Aucun enregistrement AAAA problématique trouvé")
            return True

    except Exception as e:
        print(f"❌ Erreur: {str(e)}")
        logger.error(f"Erreur lors de la vérification DNS: {str(e)}")
        return False


if __name__ == "__main__":
    print("🚀 Vérification et correction DNS airquality...")

    if check_and_fix_airquality_dns():
        print(f"\n🎉 Opération terminée avec succès!")
        print(f"⏳ Attendez 5-10 minutes puis testez :")
        print(f"   nslookup airquality.iaproject.fr")
        print(f"   curl -I https://airquality.iaproject.fr")
    else:
        print(f"\n❌ Échec de l'opération")
