#!/bin/sh
set -e
echo "     DEPUIS TRAEFIK-INIT.SH           "
echo "-------DEBUG - TRAEFIK_USERNAME = $TRAEFIK_USERNAME"
echo "-------DEBUG - TRAEFIK_PASSWORD = ${TRAEFIK_PASSWORD::-5}"


echo "Démarrage de l'initialisation Traefik..."
echo "controle des variables d'environnement"
echo "controle de la variable TRAEFIK_USERNAME"
if [ -z "$TRAEFIK_USERNAME" ]; then
  echo "ERREUR: Variable TRAEFIK_USERNAME non définie dans le fichier .env"
  exit 1
fi
echo "Utilisateur configuré: ${TRAEFIK_USERNAME}"
USER=${TRAEFIK_USERNAME}

# Créer le répertoire pour les données Traefik si nécessaire
mkdir -p ./dynamic

# Installer apache2-utils pour htpasswd
apk add --no-cache apache2-utils

# Utiliser des valeurs par défaut si les variables ne sont pas définies
echo "controle de la variable TRAEFIK_PASSWORD"
if [ -z "$TRAEFIK_PASSWORD" ]; then
  echo "ERREUR: Variable TRAEFIK_PASSWORD non définie dans le fichier .env"
  exit 1
fi
PASS=$TRAEFIK_PASSWORD

# Générer le fichier users.txt avec l'utilisateur et le mot de passe
echo "Génération du fichier users.txt..."
# htpasswd -bc ./dynamic/users.txt "$USER" "$PASS"
# echo "$USER:$(htpasswd -nb -B "$USER" "$PASS" | cut -d ":" -f 2)" > ./dynamic/users.txt
# # Alternative plus sûre
echo "${USER}:$(htpasswd -nb "${USER}" "${PASS}" | cut -d ":" -f 2)" > ./dynamic/users.txt
# Générer le fichier auth.yml pour utiliser le fichier users.txt
cat > ./dynamic/auth.yml << EOF
http:
  middlewares:
    auth-basic:
      basicAuth:
        usersFile: /etc/traefik/dynamic/users.txt
EOF

# S'assurer que le fichier acme.json existe et a les bonnes permissions
touch ./acme.json
chmod 600 ./acme.json

echo "Initialisation de Traefik terminée."
cat ./dynamic/users.txt