#!/bin/bash

# =============================================================================
# Script de vérification de la configuration Jenkins
# - Vérifie la présence des variables d'environnement critiques
# - Vérifie l'accès à Jenkins, GitLab, Docker Hub et la configuration du webhook
# =============================================================================
#
# Description:
#   Ce script vérifie la configuration de Jenkins et les connexions avec
#   GitLab et Docker Hub.
#
# Utilisation:
#   ./check-configuration.sh
# =============================================================================

echo "Vérification de la configuration Jenkins..."

# Vérification des variables d'environnement
required_vars=(
    "JENKINS_ADMIN_USER"
    "JENKINS_ADMIN_PASSWORD"
    "GITLAB_API_TOKEN"
    "DOCKER_USERNAME"
    "DOCKER_PASSWORD"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Variable $var non définie"
        exit 1
    else
        echo "✅ Variable $var définie"
    fi
done

# Vérification de l'accès à Jenkins
echo -n "Vérification de l'accès à Jenkins... "
curl -s -o /dev/null -w "%{http_code}" https://jenkins.iaproject.fr/login \
    && echo "✅" || echo "❌"

# Vérification de la connexion GitLab
echo -n "Vérification de la connexion GitLab... "
curl -s -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
    https://gitlab.com/api/v4/user \
    && echo "✅" || echo "❌"

# Vérification de la connexion Docker Hub
echo -n "Vérification de la connexion Docker Hub... "
curl -s -o /dev/null -w "%{http_code}" -u "$DOCKER_USERNAME:$DOCKER_PASSWORD" \
    https://hub.docker.com/v2/users/login/ \
    && echo "✅" || echo "❌"

# Vérification du webhook GitLab
echo "Vérification du webhook GitLab pour le projet qualité de l'air..."
curl -s -H "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
    https://gitlab.com/api/v4/projects/iaproject%2Fprojet_qualite_air/hooks \
    | grep -q "jenkins.iaproject.fr" \
    && echo "✅ Webhook GitLab configuré" \
    || echo "❌ Webhook GitLab non configuré"

echo "Vérification terminée."