#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module de configuration pour la gestion des variables d'environnement et des paramètres sensibles.

Ce module fournit une interface centralisée pour la gestion des configurations,
incluant le chargement des variables d'environnement depuis un fichier .env,
la gestion des valeurs sensibles et la création de clients API.

Classes:
    Config: Gestionnaire principal de configuration
"""

import os
import logging
from pathlib import Path
from typing import Dict, Optional, List
from logger import setup_logger, mask_sensitive


class Config:
    """
    Gestionnaire de configuration centralisé pour l'application.

    Cette classe gère le chargement et l'accès aux variables de configuration,
    avec un support spécial pour les valeurs sensibles et la création de clients API.

    Attributes:
        logger (logging.Logger): Logger configuré pour la classe
        env_file (str): Chemin vers le fichier .env
        _config (Dict[str, str]): Stockage interne des configurations
    """

    def __init__(self, env_file: str = None):
        """
        Initialise le gestionnaire de configuration.

        Args:
            env_file (str, optional): Chemin personnalisé vers le fichier .env.
                Si non spécifié, utilise le chemin par défaut dans le répertoire parent.
        """
        self.logger = setup_logger(__name__)
        self.env_file = env_file or str(Path(__file__).parent.parent / '.env')
        self._config: Dict[str, str] = {}
        self._load_config()

    def _load_config(self) -> None:
        """
        Charge les configurations depuis le fichier .env.

        Lit le fichier .env ligne par ligne, en ignorant les commentaires et les lignes vides.
        Stocke les paires clé-valeur dans le dictionnaire interne _config.

        Raises:
            Exception: Si le fichier .env ne peut pas être lu ou est mal formaté
        """
        try:
            with open(self.env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        self._config[key.strip()] = value.strip().strip("'\"")
            self.logger.info("Configuration chargée avec succès")
        except Exception as e:
            self.logger.error(
                f"Erreur lors du chargement de la configuration : {e}")
            raise

    def get(self, key: str, default: Optional[str] = None) -> str:
        """
        Récupère une valeur de configuration.

        Args:
            key (str): Clé de configuration à récupérer
            default (Optional[str]): Valeur par défaut si la clé n'existe pas

        Returns:
            str: Valeur de la configuration ou valeur par défaut

        Note:
            Les valeurs sensibles sont masquées dans les logs
        """
        value = self._config.get(key, default)
        if value is not None and key in [
                'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
                'OVH_CONSUMER_KEY'
        ]:
            self.logger.debug(
                f"Récupération de {key} : {mask_sensitive(value)}")
        return value

    def get_required(self, key: str) -> str:
        """
        Récupère une valeur de configuration requise.

        Args:
            key (str): Clé de configuration requise

        Returns:
            str: Valeur de la configuration

        Raises:
            KeyError: Si la clé n'existe pas dans la configuration
        """
        if key not in self._config:
            self.logger.error(f"Configuration requise manquante : {key}")
            raise KeyError(f"Configuration requise manquante : {key}")
        value = self._config[key]
        if key in [
                'OVH_APPLICATION_KEY', 'OVH_APPLICATION_SECRET',
                'OVH_CONSUMER_KEY'
        ]:
            self.logger.debug(
                f"Récupération de {key} : {mask_sensitive(value)}")
        return value

    def check_required_vars(self, required_vars: List[str]) -> bool:
        """
        Vérifie la présence de toutes les variables de configuration requises.

        Args:
            required_vars (List[str]): Liste des variables requises

        Returns:
            bool: True si toutes les variables sont présentes, False sinon
        """
        missing = [var for var in required_vars if var not in self._config]
        if missing:
            self.logger.error(
                f"Variables de configuration manquantes : {', '.join(missing)}"
            )
            return False
        self.logger.info("Toutes les variables requises sont présentes")
        return True

    def get_ovh_client(self):
        """
        Crée et retourne un client OVH configuré.

        Returns:
            ovh.Client: Client OVH initialisé avec les credentials

        Raises:
            Exception: Si la création du client échoue
        """
        import ovh
        try:
            client = ovh.Client(
                endpoint='ovh-eu',
                application_key=self.get_required('OVH_APPLICATION_KEY'),
                application_secret=self.get_required('OVH_APPLICATION_SECRET'),
                consumer_key=self.get_required('OVH_CONSUMER_KEY'))
            self.logger.info("Client OVH configuré avec succès")
            return client
        except Exception as e:
            self.logger.error(
                f"Erreur lors de la configuration du client OVH : {e}")
            raise


# Instance globale de configuration
config = Config()
