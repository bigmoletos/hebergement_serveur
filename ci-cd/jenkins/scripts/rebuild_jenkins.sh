#!/bin/bash

# Arrêt du conteneur Jenkins actuel
echo "Arrêt du conteneur Jenkins..."
docker stop jenkins || true
docker rm jenkins || true

# Construction de la nouvelle image
echo "Construction de la nouvelle image Jenkins..."
cd "$(dirname "$0")/.."
docker build -t jenkins-python:latest .

# Démarrage du nouveau conteneur Jenkins
echo "Démarrage du nouveau conteneur Jenkins..."
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  --network traefik-public \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e JENKINS_OPTS="--prefix=/jenkins" \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.jenkins.rule=Host(\`jenkins.airquality.iaproject.fr\`)" \
  --label "traefik.http.routers.jenkins.entrypoints=websecure" \
  --label "traefik.http.routers.jenkins.tls=true" \
  --label "traefik.http.routers.jenkins.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.jenkins.loadbalancer.server.port=8080" \
  jenkins-python:latest

echo "Jenkins a été redémarré avec succès. Veuillez attendre quelques instants que le service démarre complètement."
echo "Vous pouvez accéder à Jenkins à l'adresse : https://jenkins.airquality.iaproject.fr"