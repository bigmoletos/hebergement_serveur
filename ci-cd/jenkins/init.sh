#!/bin/bash
# =====================================================
# Script d'initialisation du conteneur Jenkins
# - Vérifie et corrige les permissions des dossiers critiques
# - Ajoute dynamiquement tous les sous-dossiers Jenkins comme safe.directory pour Git
# - Lance le script de support Jenkins
# =====================================================
# Auteur : [Votre nom]
# Date : [Date de modification]
# =====================================================
set -e

echo "=== [INIT.SH] Début de l'initialisation Jenkins ==="

# Fonction pour vérifier et corriger les permissions
fix_permissions() {
    local dir=$1
    echo "Vérification des permissions pour ${dir}..."

    # Vérification si le répertoire existe
    if [ ! -d "$dir" ]; then
        echo "Création du répertoire ${dir}"
        mkdir -p "$dir"
    fi

    # Vérification des permissions
    if [ "$(stat -c %U:%G $dir)" != "jenkins:jenkins" ]; then
        echo "Correction des permissions pour ${dir}"
        sudo chown -R jenkins:jenkins "$dir"
    fi
}

# Vérification des permissions pour les répertoires critiques
fix_permissions "/var/jenkins_home"
fix_permissions "/var/jenkins_config"

echo "=== [INIT.SH] Configuration des safe.directory Git ==="
find /var/jenkins_home/workspace -type d -path "*/build-and-deploy@script/*" | while read dir; do
    echo "Ajout du safe.directory : $dir"
    git config --global --add safe.directory "$dir"
done

echo "=== [INIT.SH] Fin de l'initialisation, lancement de jenkins-support.sh ==="

# Exécution du script de support Jenkins
exec /usr/local/bin/jenkins-support.sh "$@"