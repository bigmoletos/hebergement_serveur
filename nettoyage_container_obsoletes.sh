# /projet_qualite_air/scripts/cleanup_docker_images.sh
#!/bin/bash

# Configuration
REPOSITORY_IHM="bigmoletos/air_quality_ihm"
REPOSITORY_API="bigmoletos/air_quality_api"
KEEP_TAGS=3

cleanup_repository() {
    local repo=$1
    echo "Nettoyage du repository: $repo"

    # Garder uniquement les N dernières versions (exclure latest et *_test)
    tags=$(docker images $repo --format "{{.Tag}}" | grep -vE '^(latest|.*_test)$' | sort -r)

    # Compter le nombre de tags
    total_tags=$(echo "$tags" | wc -l)

    if [ "$total_tags" -gt "$KEEP_TAGS" ]; then
        echo "Suppression des anciennes images..."
        echo "$tags" | tail -n +$((KEEP_TAGS + 1)) | xargs -I {} docker rmi $repo:{} || true
    fi
}

# Nettoyer les images
cleanup_repository $REPOSITORY_IHM
cleanup_repository $REPOSITORY_API

# Nettoyer les images dangling
echo "Nettoyage des images dangling..."
docker image prune -f

echo "Nettoyage terminé"