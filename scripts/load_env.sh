#!/bin/bash

# =====================================================
# Script de chargement des variables d'environnement
# Ce script charge les variables d'environnement depuis
# un fichier .env et les exporte dans l'environnement
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-12
# Version: 1.0.0

# =====================================================
# Fonction de masquage des informations sensibles
# =====================================================
mask_sensitive() {
    local value="$1"
    local visible_chars=5
    if [ -z "$value" ]; then
        echo "***"
    else
        echo "${value:0:$visible_chars}***"
    fi
}

# =====================================================
# Fonction de chargement des variables d'environnement
# =====================================================
load_env() {
    local var_name="$1"
    local debug_mode="${2:-false}"
    local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local env_file="$script_dir/../.env"
    local temp_file="/tmp/tmp.$(date +%s).env"

    if [ ! -f "$env_file" ]; then
        echo "Erreur: Fichier .env non trouvé dans $env_file"
        return 1
    fi

    # Création d'un fichier temporaire sans commentaires et lignes vides
    grep -v '^#' "$env_file" | grep -v '^$' > "$temp_file"

    # Recherche de la variable
    local value=$(grep "^$var_name=" "$temp_file" | cut -d'=' -f2- | sed "s/^['\"]//;s/['\"]$//")

    # Suppression du fichier temporaire
    rm -f "$temp_file"

    if [ -z "$value" ]; then
        return 1
    fi

    echo "$value"
    return 0
}

# =====================================================
# Vérification des paramètres
# =====================================================
if [ $# -eq 0 ]; then
    echo "Usage: source load_env.sh [VARIABLE] [debug]"
    echo "Exemple: source load_env.sh OVH_APPLICATION_KEY debug"
    return 1
fi

# =====================================================
# Chargement de la variable demandée
# =====================================================
var_name="$1"
debug_mode="${2:-false}"

value=$(load_env "$var_name" "$debug_mode")
if [ $? -ne 0 ]; then
    return 1
fi

# =====================================================
# Exportation de la variable
# =====================================================
export "$var_name=$value"
echo "$value"
return 0