#!/bin/sh
set -e

echo "Démarrage de l'initialisation Traefik..."
echo "Utilisateur configuré: ${TRAEFIK_USER:-admin}"

# Créer le répertoire pour les données Traefik si nécessaire
mkdir -p ./dynamic

# Installer apache2-utils pour htpasswd
apk add --no-cache apache2-utils

# Utiliser des valeurs par défaut si les variables ne sont pas définies
USER=${TRAEFIK_USER:-admin}
PASS=${TRAEFIK_PASSWORD:-test123}

# Générer le fichier users.txt avec l'utilisateur et le mot de passe
echo "Génération du fichier users.txt..."
htpasswd -bc ./dynamic/users.txt "$USER" "$PASS"

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