#!/bin/bash
set -e

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

# Exécution du script de support Jenkins
exec /usr/local/bin/jenkins-support.sh "$@"