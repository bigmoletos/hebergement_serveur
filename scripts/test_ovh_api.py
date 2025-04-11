import hashlib
import time
import os
from dotenv import load_dotenv
from pathlib import Path

# Chemin vers le fichier .env
env_path = Path(__file__).parent.parent / '.env'
print(f"Recherche du fichier .env dans : {env_path}")

# Charger les variables d'environnement
load_dotenv(dotenv_path=env_path)

# Récupérer les clés depuis les variables d'environnement
application_key = os.getenv('OVH_APPLICATION_KEY')
application_secret = os.getenv('OVH_APPLICATION_SECRET')
consumer_key = os.getenv('OVH_CONSUMER_KEY')

# Vérification des variables
if not all([application_key, application_secret, consumer_key]):
    print("ERREUR: Variables d'environnement manquantes:")
    print(f"OVH_APPLICATION_KEY: {application_key}")
    print(f"OVH_APPLICATION_SECRET: {application_secret}")
    print(f"OVH_CONSUMER_KEY: {consumer_key}")
    exit(1)

# Paramètres de la requête
method = 'GET'
url = '/domain/zone/airquality.iaproject.fr/record'
timestamp = str(int(time.time()))

# Calcul de la signature
text = f"{application_secret}+{consumer_key}+{method}+{url}+{timestamp}"
signature = "$1$" + hashlib.sha1(text.encode('utf-8')).hexdigest()

print("\nHeaders à utiliser dans Postman :")
print("--------------------------------")
print(f"X-Ovh-Application: {application_key}")
print(f"X-Ovh-Consumer: {consumer_key}")
print(f"X-Ovh-Timestamp: {timestamp}")
print(f"X-Ovh-Signature: {signature}")
