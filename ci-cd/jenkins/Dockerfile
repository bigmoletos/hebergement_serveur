FROM jenkins/jenkins:lts

USER root

# Installation des dépendances système
RUN apt-get update && \
    apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    docker.io \
    docker-compose \
    ansible \
    git \
    && rm -rf /var/lib/apt/lists/*

# Configuration de Python
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PYTHON_VERSION=3.9

# Installation des dépendances Python globales
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install pytest pytest-cov

# Ajout de l'utilisateur jenkins au groupe docker
RUN usermod -aG docker jenkins

# Configuration des permissions
RUN mkdir -p /var/jenkins_home/.docker && \
    chown -R jenkins:jenkins /var/jenkins_home/.docker

USER jenkins