#!/bin/bash

# Création du réseau proxy si non existant
if ! docker network ls | grep -q "proxy"; then
    docker network create proxy
fi

# Création du réseau traefik_public si non existant
if ! docker network ls | grep -q "traefik_public"; then
    docker network create traefik_public
fi

echo "Les réseaux Docker ont été configurés avec succès."