#!/bin/sh
set -e

# Afficher les variables pour debug
echo "*** DEBUG ENTRYPOINT - ENV ****"
echo ""
env | grep TRAEFIK
echo ""
echo " *** FIN DEBUG ENTRYPOINT - ENV ****"

echo ""
echo " Fonction pour lire le fichier .env directement ****"
# Fonction pour lire le fichier .env directement
load_env_file() {
  if [ -f "/app/.env" ]; then
    echo "Lecture directe du fichier .env..."
    TRAEFIK_USERNAME=$(grep "^TRAEFIK_USERNAME=" /app/.env | cut -d '=' -f 2)
    TRAEFIK_PASSWORD=$(grep "^TRAEFIK_PASSWORD=" /app/.env | cut -d '=' -f 2)

    # Exporter les variables pour les rendre disponibles aux sous-processus
    export TRAEFIK_USERNAME
    export TRAEFIK_PASSWORD

    echo "Variables chargées depuis le fichier .env:"
    echo "TRAEFIK_USERNAME=$TRAEFIK_USERNAME"
    echo "TRAEFIK_PASSWORD=${TRAEFIK_PASSWORD::-6}"
    return 0
  else
    echo "ERREUR: Fichier .env introuvable"
    return 1
  fi
}

echo ""
echo " ***Vérifier si les variables nécessaires sont définies ****"
# Vérifier si les variables nécessaires sont définies
if [ -z "$TRAEFIK_PASSWORD" ] || [ -z "$TRAEFIK_USERNAME" ]; then
  echo "Variables manquantes, tentative de lecture du fichier .env..."
  load_env_file
fi

echo ""
echo " *** Vérifier à nouveau les variables ****"
# Vérifier à nouveau les variables
if [ -z "$TRAEFIK_PASSWORD" ] || [ -z "$TRAEFIK_USERNAME" ]; then
  echo "ERREUR: Variables requises toujours non définies après tentative de chargement"
  exit 1
fi

echo ""
echo " *** Lancer le script d'initialisation ****"

# Lancer le script d'initialisation
sh /init.sh
