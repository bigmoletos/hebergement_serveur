#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module de logging pour les scripts Python
Ce module fournit des fonctions de logging réutilisables
"""

import logging
import os
import sys
import traceback
from typing import List, Optional, Any


# =====================================================
# Configuration du logger
# =====================================================
def setup_logger(name: str,
                 log_file: str = None,
                 level: int = logging.INFO) -> logging.Logger:
    """
    Configure et retourne un logger personnalisé

    Args:
        name (str): Nom du logger
        log_file (str, optional): Chemin du fichier de log. Defaults to None.
        level (int, optional): Niveau de log. Defaults to logging.INFO.

    Returns:
        logging.Logger: Logger configuré
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)

    # Format des messages
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

    # Handler pour la console
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # Handler pour le fichier si spécifié
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    return logger


# =====================================================
# Fonction de masquage des informations sensibles
# =====================================================
def mask_sensitive(value: str, visible_chars: int = 5) -> str:
    """
    Masque une valeur sensible en ne gardant que les premiers caractères

    Args:
        value (str): Valeur à masquer
        visible_chars (int, optional): Nombre de caractères visibles. Defaults to 5.

    Returns:
        str: Valeur masquée
    """
    if not value:
        return "***"
    return value[:visible_chars] + "***"


# =====================================================
# Fonction de vérification des variables d'environnement
# =====================================================
def check_required_vars(required_vars: List[str],
                        logger: logging.Logger) -> bool:
    """
    Vérifie la présence des variables d'environnement requises

    Args:
        required_vars (List[str]): Liste des variables requises
        logger (logging.Logger): Logger pour les messages

    Returns:
        bool: True si toutes les variables sont présentes, False sinon
    """
    missing_vars = []

    for var in required_vars:
        if var not in os.environ:
            missing_vars.append(var)
        else:
            # Masquage des valeurs sensibles dans les logs
            if 'KEY' in var or 'SECRET' in var or 'PASSWORD' in var:
                logger.info(
                    f"Variable {var} trouvée : {mask_sensitive(os.environ[var])}"
                )
            else:
                logger.info(f"Variable {var} trouvée : {os.environ[var]}")

    if missing_vars:
        logger.error(f"Variables manquantes : {', '.join(missing_vars)}")
        return False

    return True


# =====================================================
# Fonction de gestion des exceptions
# =====================================================
def log_exception(logger: logging.Logger,
                  error: Exception,
                  context: str = "") -> None:
    """
    Log une exception avec son contexte et sa trace

    Args:
        logger (logging.Logger): Logger pour les messages
        error (Exception): Exception à logger
        context (str, optional): Contexte de l'erreur. Defaults to "".
    """
    if context:
        logger.error(f"{context}: {str(error)}")
    else:
        logger.error(f"Erreur: {str(error)}")
    logger.error(f"Traceback: {traceback.format_exc()}")


# =====================================================
# Fonction de vérification de l'existence d'un fichier
# =====================================================
def check_file_exists(file_path: str, logger: logging.Logger) -> bool:
    """
    Vérifie l'existence d'un fichier

    Args:
        file_path (str): Chemin du fichier
        logger (logging.Logger): Logger pour les messages

    Returns:
        bool: True si le fichier existe, False sinon
    """
    if not os.path.isfile(file_path):
        logger.error(f"Fichier non trouvé : {file_path}")
        return False
    return True


# =====================================================
# Fonction de vérification de l'existence d'un répertoire
# =====================================================
def check_directory_exists(dir_path: str,
                           logger: logging.Logger,
                           create: bool = False) -> bool:
    """
    Vérifie l'existence d'un répertoire et le crée si demandé

    Args:
        dir_path (str): Chemin du répertoire
        logger (logging.Logger): Logger pour les messages
        create (bool, optional): Créer le répertoire s'il n'existe pas. Defaults to False.

    Returns:
        bool: True si le répertoire existe ou a été créé, False sinon
    """
    if not os.path.isdir(dir_path):
        if create:
            try:
                os.makedirs(dir_path)
                logger.info(f"Répertoire créé : {dir_path}")
                return True
            except Exception as e:
                logger.error(
                    f"Impossible de créer le répertoire {dir_path}: {str(e)}")
                return False
        else:
            logger.error(f"Répertoire non trouvé : {dir_path}")
            return False
    return True


# =====================================================
# Fonction de vérification des privilèges root
# =====================================================
def check_root(logger: logging.Logger) -> bool:
    """
    Vérifie si le script est exécuté en tant que root

    Args:
        logger (logging.Logger): Logger pour les messages

    Returns:
        bool: True si root, False sinon
    """
    if os.geteuid() != 0:
        logger.error("Ce script doit être exécuté en tant que root")
        return False
    return True
