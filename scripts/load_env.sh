#!/bin/bash

# =====================================================
# Script de chargement des variables d'environnement
# Ce script centralise la logique de chargement des
# variables d'environnement depuis le fichier .env
#
# Objectifs :
# 1. Charger les variables depuis le fichier .env
# 2. Préserver les guillemets pour les mots de passe
# 3. Nettoyer les autres variables
# 4. Gérer l'absence du fichier .env
# 5. Permettre la recherche d'une variable spécifique
# 6. Gérer les niveaux de log
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-12
# Version: 1.0.0

# =====================================================
# Configuration des couleurs pour les messages
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# =====================================================
# Fonctions d'affichage des messages
# =====================================================
log_message() {
    if [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ]; then
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_error() {
    if [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "error" ]; then
        echo -e "${RED}[ERREUR]${NC} $1"
    fi
}

log_warning() {
    if [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "warning" ]; then
        echo -e "${YELLOW}[ATTENTION]${NC} $1"
    fi
}

# =====================================================
# Fonction pour lire le niveau de log depuis .env
# =====================================================
get_log_level() {
    local env_file="/hebergement_serveur/.env"
    if [ -f "$env_file" ]; then
        local log_level=$(grep "^LOG_LEVEL=" "$env_file" | cut -d '=' -f 2 | tr -d '[:space:]')
        echo "${log_level:-"info"}"
    else
        echo "info"
    fi
}

# =====================================================
# Fonction principale de chargement des variables
# =====================================================
load_env() {
    local search_var="$1"  # Variable à rechercher
    local log_level="$2"   # Niveau de log (debug, info, warning, error)

    # Définition du niveau de log
    LOG_LEVEL=${log_level:-$(get_log_level)}

    # Vérification des paramètres
    if [ -z "$search_var" ]; then
        log_error "Paramètre manquant"
        log_message "Usage: ./load_env.sh <variable_à_rechercher> [niveau_de_log]"
        log_message "Exemple: ./load_env.sh OVH_APPLICATION_KEY debug"
        return 1
    fi

    # Chemin du fichier .env
    local env_file="/hebergement_serveur/.env"

    if [ -f "$env_file" ]; then
        if [ "$LOG_LEVEL" = "debug" ]; then
            log_message "Tentative de chargement depuis : $env_file"
            log_message "Répertoire courant : $(pwd)"
            log_message "Contenu du répertoire :"
            ls -la "/hebergement_serveur"
            log_message "Contenu du fichier .env :"
            cat "$env_file"
        fi

        # Création d'un fichier temporaire nettoyé
        local temp_file=$(mktemp)
        if [ "$LOG_LEVEL" = "debug" ]; then
            log_message "Création du fichier temporaire : $temp_file"
        fi

        # Nettoyage du fichier .env
        if [ "$LOG_LEVEL" = "debug" ]; then
            log_message "Nettoyage du fichier .env..."
        fi
        # Supprimer les lignes vides et les commentaires
        grep -v '^[[:space:]]*#' "$env_file" | grep -v '^[[:space:]]*$' > "$temp_file"

        if [ "$LOG_LEVEL" = "debug" ]; then
            log_message "Contenu nettoyé du fichier .env :"
            cat "$temp_file"
        fi

        # Lecture du fichier nettoyé
        if [ "$LOG_LEVEL" = "debug" ]; then
            log_message "Recherche de la variable : $search_var"
        fi

        while IFS= read -r line; do
            # Extraire la clé et la valeur
            key=$(echo "$line" | cut -d '=' -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$line" | cut -d '=' -f 2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Vérifier que la ligne contient bien une clé et une valeur
            if [[ -n "$key" && -n "$value" ]]; then
                if [ "$LOG_LEVEL" = "debug" ]; then
                    log_message "Variable trouvée : $key=${value:0:4}..."  # Afficher seulement les 4 premiers caractères pour la sécurité
                fi

                # Si c'est la variable recherchée
                if [ "$key" = "$search_var" ]; then
                    # Suppression du fichier temporaire
                    rm -f "$temp_file"
                    if [ "$LOG_LEVEL" = "debug" ]; then
                        log_message "Fichier temporaire supprimé"
                    fi
                    echo "$value"
                    return 0
                fi
            fi
        done < "$temp_file"

        # Suppression du fichier temporaire
        rm -f "$temp_file"
        if [ "$LOG_LEVEL" = "debug" ]; then
            log_message "Fichier temporaire supprimé"
        fi

        log_error "Variable non trouvée : $search_var"
        return 1
    else
        log_error "Le fichier $env_file n'existe pas"
        return 1
    fi
}

# Si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_env "$1" "$2"
    exit $?
fi