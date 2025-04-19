#!/bin/sh

# Charger les variables d'environnement depuis .env
. ../.env

# Vérifier si la variable est définie
if [ -z "$TRAEFIK_BASIC_AUTH" ]; then
  echo "ERREUR: Variable TRAEFIK_BASIC_AUTH non définie dans le fichier .env"
  exit 1
fi

# Créer le fichier de configuration d'authentification
cat > ./dynamic/auth.yml << EOF
http:
  middlewares:
    auth-basic:
      basicAuth:
        users:
          - "$TRAEFIK_BASIC_AUTH"
EOF

echo "Fichier de configuration d'authentification généré avec succès."