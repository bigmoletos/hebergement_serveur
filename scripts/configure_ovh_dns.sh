#!/bin/bash

# =============================================================================
# Script de configuration DNS OVH
# =============================================================================
#
# Description:
#   Ce script configure automatiquement les enregistrements DNS pour tous les
#   sous-domaines des services hébergés sur le serveur via l'API OVH.
#
# Utilisation:
#   ./configure_ovh_dns.sh
#
# Variables d'environnement requises (.env):
#   - OVH_APPLICATION_KEY: Clé d'application OVH
#   - OVH_APPLICATION_SECRET: Secret d'application OVH
#   - OVH_CONSUMER_KEY: Clé consommateur OVH
#   - IP_FREEBOX: Adresse IP publique du serveur
#
# Structure des sous-domaines:
#   - Applications: airquality, prediction-vent, api-meteo
#   - Services: portainer, jenkins, vault, traefik
#   - Monitoring: grafana, prometheus
#
# Auteur: Bigmoletos
# Date: [Date de création]
# Version: 1.0
# =============================================================================

# Fonction pour générer la signature OVH
# @param $1 Méthode HTTP (GET, POST, PUT, DELETE)
# @param $2 URL complète de l'API
# @param $3 Corps de la requête (optionnel)
# @return Signature générée pour l'authentification OVH
generate_signature() {
    local method=$1
    local url=$2
    local body=$3
    local timestamp=$(date +%s)

    if [ -z "$body" ]; then
        body=""
    fi

    local signature="\$1\$$(echo -n "${OVH_APPLICATION_SECRET}+${OVH_CONSUMER_KEY}+${method}+${url}+${body}+${timestamp}" | sha1sum | cut -d' ' -f1)"
    echo "$signature"
}

# Fonction pour effectuer les appels API OVH
# @param $1 Méthode HTTP
# @param $2 Endpoint de l'API (sans le préfixe https://api.ovh.com/1.0)
# @param $3 Corps de la requête (optionnel)
# @return Réponse de l'API OVH
call_ovh_api() {
    local method=$1
    local endpoint=$2
    local body=$3

    local url="https://api.ovh.com/1.0${endpoint}"
    local timestamp=$(date +%s)
    local signature=$(generate_signature "$method" "$url" "$body")

    echo "DEBUG: Appel API OVH"
    echo "- Méthode: $method"
    echo "- URL: $url"
    echo "- Timestamp: $timestamp"
    echo "- Signature: ${signature:0:20}..."

    local curl_cmd="curl -s -v -X $method \"$url\" \
        -H \"X-Ovh-Application: $OVH_APPLICATION_KEY\" \
        -H \"X-Ovh-Consumer: $OVH_CONSUMER_KEY\" \
        -H \"X-Ovh-Timestamp: $timestamp\" \
        -H \"X-Ovh-Signature: $signature\""

    if [ ! -z "$body" ]; then
        curl_cmd="$curl_cmd -H \"Content-Type: application/json\" -d '$body'"
        echo "- Body: $body"
    fi

    echo "Exécution de la requête..."
    local response=$(eval $curl_cmd 2>&1)
    local curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo "Erreur curl (code $curl_exit_code): $response"
        return 1
    fi

    if [[ "$response" == *"\"errorCode\""* ]]; then
        echo "Erreur API OVH: $response"
        return 1
    fi

    echo "$response"
}

# Chargement des variables depuis .env
ENV_FILE="/hebergement_serveur/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Chargement des variables depuis $ENV_FILE"
    while IFS='=' read -r key value; do
        # Ignorer les lignes vides et les commentaires
        if [[ $key =~ ^[[:space:]]*$ ]] || [[ $key =~ ^# ]]; then
            continue
        fi
        # Supprimer les guillemets et les espaces
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        # Exporter la variable
        export "$key=$value"
    done < "$ENV_FILE"
else
    echo "Erreur: Fichier $ENV_FILE non trouvé"
    exit 1
fi

# Liste des sous-domaines à configurer
SUBDOMAINS=(
    # Applications
    "airquality"
    "prediction-vent"
    "api-meteo"

    # Services de Gestion
    "portainer"
    "jenkins"
    "vault"
    "traefik"

    # Monitoring
    "grafana"
    "prometheus"
)

# Vérification des variables d'environnement requises
if [ -z "$OVH_APPLICATION_KEY" ] || [ -z "$OVH_APPLICATION_SECRET" ] || [ -z "$OVH_CONSUMER_KEY" ]; then
    echo "Erreur: Variables OVH manquantes dans le fichier .env"
    echo "Vérifiez que les variables suivantes sont définies:"
    echo "- OVH_APPLICATION_KEY: ${OVH_APPLICATION_KEY:-(non définie)}"
    echo "- OVH_APPLICATION_SECRET: ${OVH_APPLICATION_SECRET:-(non définie)}"
    echo "- OVH_CONSUMER_KEY: ${OVH_CONSUMER_KEY:-(non définie)}"
    exit 1
fi

if [ -z "$IP_FREEBOX" ]; then
    echo "Erreur: Variable IP_FREEBOX manquante dans le fichier .env"
    exit 1
fi

echo "Configuration des sous-domaines pour les services avec:"
echo "- IP du serveur: $IP_FREEBOX"
echo "- Clé d'application OVH: ${OVH_APPLICATION_KEY:0:5}..."

# Test de l'API OVH
echo "Test de connexion à l'API OVH..."
echo "Vérification des variables d'authentification:"
echo "- OVH_APPLICATION_KEY: ${OVH_APPLICATION_KEY:0:5}..."
echo "- OVH_APPLICATION_SECRET: ${OVH_APPLICATION_SECRET:0:5}..."
echo "- OVH_CONSUMER_KEY: ${OVH_CONSUMER_KEY:0:5}..."

test_response=$(call_ovh_api "GET" "/auth/time")
if ! [[ "$test_response" =~ ^[0-9]+$ ]]; then
    echo "Erreur de connexion à l'API OVH."
    echo "Réponse complète: $test_response"
    echo ""
    echo "Vérifiez que:"
    echo "1. Les clés API sont correctes"
    echo "2. Les clés ont les droits nécessaires sur l'API OVH"
    echo "3. Le compte OVH est actif"
    echo "4. L'API OVH est accessible"
    exit 1
fi
echo "Connexion à l'API OVH réussie (timestamp: $test_response)"

for subdomain in "${SUBDOMAINS[@]}"; do
    echo "Configuration de $subdomain.iaproject.fr..."

    # Vérification de l'existence du sous-domaine
    records_response=$(call_ovh_api "GET" "/domain/zone/iaproject.fr/record?fieldType=A&subDomain=$subdomain")

    if [ "$records_response" == "[]" ]; then
        # Création du sous-domaine
        create_body="{\"fieldType\":\"A\",\"subDomain\":\"$subdomain\",\"target\":\"$IP_FREEBOX\",\"ttl\":0}"
        response=$(call_ovh_api "POST" "/domain/zone/iaproject.fr/record" "$create_body")

        if [[ $response == *"\"id\""* ]]; then
            record_id=$(echo $response | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
            echo "Sous-domaine $subdomain.iaproject.fr créé avec succès (ID: $record_id)"
        else
            echo "Erreur lors de la création de $subdomain.iaproject.fr: $response"
        fi
    else
        # Mise à jour du sous-domaine existant
        record_id=$(echo $records_response | grep -o '\[.*\]' | grep -o '[0-9]*')
        if [ ! -z "$record_id" ]; then
            update_body="{\"target\":\"$IP_FREEBOX\"}"
            response=$(call_ovh_api "PUT" "/domain/zone/iaproject.fr/record/$record_id" "$update_body")
            echo "Sous-domaine $subdomain.iaproject.fr mis à jour (ID: $record_id)"
        fi
    fi
done

# Rafraîchissement de la zone DNS
echo "Rafraîchissement de la zone DNS..."
refresh_response=$(call_ovh_api "POST" "/domain/zone/iaproject.fr/refresh")
if [ -z "$refresh_response" ]; then
    echo "Zone DNS rafraîchie avec succès"
else
    echo "Erreur lors du rafraîchissement de la zone DNS: $refresh_response"
fi

echo "Configuration terminée. Attente de la propagation DNS (peut prendre jusqu'à 24h)..."