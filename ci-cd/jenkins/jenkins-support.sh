#!/bin/bash
# =====================================================
# Script de support pour le démarrage de Jenkins
# - Vérifie la disponibilité du port 8080
# - Lance Jenkins avec les options configurées
# =====================================================
set -e

# Fonction pour vérifier si le port est disponible
check_port() {
    local port=$1
    local retries=30
    local wait=1

    echo "Vérification de la disponibilité du port ${port}..."

    while [ $retries -gt 0 ]; do
        if ! nc -z localhost $port; then
            return 0
        fi
        echo "Port ${port} est occupé, attente de ${wait} secondes..."
        sleep $wait
        retries=$((retries-1))
    done

    echo "Erreur: Le port ${port} n'est pas devenu disponible"
    return 1
}

# Vérification du port 8080
check_port 8080

# Démarrage de Jenkins avec les options configurées
exec /usr/local/bin/jenkins.sh "$@"