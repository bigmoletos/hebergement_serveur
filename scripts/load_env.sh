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
# =====================================================

# Auteur: Franck DESMEDT
# Date: 2025-04-11
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
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

# =====================================================
# Fonction principale de chargement des variables
# =====================================================
load_env() {
    local env_file="${1:-.env}"  # Utilise .env par défaut si aucun argument n'est fourni
    local env_dir="${2:-$(pwd)}" # Utilise le répertoire courant par défaut

    # Construction du chemin complet
    local full_path="${env_dir}/${env_file}"

    log_message "Tentative de chargement depuis : $full_path"
    log_message "Répertoire courant : $(pwd)"
    log_message "Contenu du répertoire :"
    ls -la "$env_dir"

    if [ -f "$full_path" ]; then
        log_message "Fichier .env trouvé, début du chargement..."
        # Lecture ligne par ligne du fichier .env
        while IFS= read -r line; do
            # Ignorer les lignes vides et les commentaires
            if [[ -z "$line" ]]; then
                log_warning "Ligne vide ignorée"
                continue
            fi
            if [[ "$line" =~ ^# ]]; then
                log_warning "Commentaire ignoré : $line"
                continue
            fi

            # Extraire la clé et la valeur (tout avant le premier #)
            key=$(echo "$line" | cut -d '=' -f 1 | tr -d ' ' | tr -d '"' | tr -d "'")
            log_message "Traitement de la clé : $key"

            # Pour les mots de passe, préserver les guillemets
            if [[ "$key" == *"PASSWORD"* || "$key" == *"SECRET"* ]]; then
                value=$(echo "$line" | cut -d '=' -f 2- | cut -d '#' -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                log_message "Valeur (mot de passe) : $value"
            else
                value=$(echo "$line" | cut -d '=' -f 2- | cut -d '#' -f 1 | tr -d ' ' | tr -d '"' | tr -d "'")
                log_message "Valeur : $value"
            fi

            # Vérifier que la ligne contient bien une clé et une valeur
            if [[ -n "$key" && -n "$value" ]]; then
                # Exporter la variable
                export "$key=$value"
                log_message "Variable exportée : $key=$value"
            else
                log_warning "Ligne ignorée (clé ou valeur vide) : $line"
            fi
        done < "$full_path"

        # Vérification des variables importantes
        log_message "Vérification des variables importantes..."
        if [ -z "$SERVER_USER" ]; then
            log_warning "SERVER_USER n'est pas défini dans le fichier .env"
            log_warning "Contenu du fichier .env :"
            cat "$full_path"
        else
            log_message "SERVER_USER est défini : $SERVER_USER"
        fi
    else
        log_warning "Le fichier $full_path n'existe pas. Utilisation des valeurs par défaut."
        log_warning "Contenu du répertoire :"
        ls -la "$env_dir"
    fi
}

# Si le script est exécuté directement, charger les variables
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_env "$@"
fi