#!/bin/bash

# =====================================================
# Script de fonctions de logging
# Ce script fournit des fonctions de logging réutilisables
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
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

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
# Fonction de vérification des privilèges root
# =====================================================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

# =====================================================
# Fonction de vérification des variables d'environnement
# =====================================================
check_required_vars() {
    local vars=("$@")
    local missing_vars=()

    for var in "${vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Variables manquantes : ${missing_vars[*]}"
        return 1
    fi

    return 0
}

# =====================================================
# Fonction de vérification de l'état d'un service
# =====================================================
check_service_status() {
    local service_name="$1"
    local container_name="$2"

    if docker ps | grep -q "$container_name"; then
        log_message "$service_name est en cours d'exécution"
        return 0
    else
        log_error "$service_name n'est pas en cours d'exécution"
        return 1
    fi
}

# =====================================================
# Fonction de création de répertoire avec vérification
# =====================================================
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        if [ $? -eq 0 ]; then
            log_message "Répertoire créé : $dir"
        else
            log_error "Impossible de créer le répertoire : $dir"
            return 1
        fi
    fi
    return 0
}

# =====================================================
# Fonction de vérification de l'existence d'un fichier
# =====================================================
check_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "Fichier non trouvé : $file"
        return 1
    fi
    return 0
}

# =====================================================
# Fonction de vérification de l'exécution d'une commande
# =====================================================
execute_command() {
    local cmd="$1"
    local description="$2"

    log_message "Exécution : $description"
    eval "$cmd"
    local status=$?

    if [ $status -eq 0 ]; then
        log_message "Succès : $description"
    else
        log_error "Échec : $description (code: $status)"
    fi

    return $status
}