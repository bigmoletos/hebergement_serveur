# Guide d'Installation et Configuration du Serveur

## 0. Architecture et Organisation des Scripts

Le système est organisé en modules indépendants, chacun gérant une partie spécifique de l'infrastructure :

1. **Scripts de Configuration** :
   - `pre-requis.sh` : Installation des dépendances système
   - `configure_ovh_dns.sh` : Gestion DNS via API OVH
   - `configure_traefik.sh` : Configuration du reverse proxy
   - `install_server.sh` : Orchestration globale

2. **Structure des Répertoires** :
   ```
   /hebergement_serveur/
   ├── config/              # Configurations
   │   ├── traefik/        # Configuration de Traefik
   │   ├── docker-compose/ # Fichiers docker-compose
   │   └── env/           # Variables d'environnement
   ├── data/               # Données persistantes
   │   ├── portainer/     # Données de Portainer
   │   └── monitoring/    # Données de monitoring
   ├── logs/              # Logs centralisés
   ├── certs/             # Certificats SSL
   └── scripts/           # Scripts de maintenance
   ```

## 1. Ordre d'exécution des scripts

L'installation complète du serveur se fait en quatre étapes principales, dans cet ordre :

1. **Prérequis** (`pre-requis.sh`) :
   ```bash
   sudo ./pre-requis.sh
   ```
   - Met à jour le système
   - Installe les dépendances (Docker, Docker Compose)
   - Configure la sécurité de base
   - Crée la structure des dossiers
   - Configure le pare-feu

2. **Configuration DNS OVH** (`configure_ovh_dns.sh`) :
   ```bash
   sudo ./configure_ovh_dns.sh
   ```
   - Configure l'authentification OVH
   - Met en place la mise à jour DNS automatique via l'API OVH
   - Crée une tâche cron pour la surveillance de l'IP
   - Gère la mise à jour des enregistrements DNS
   - Teste la connexion à l'API OVH

3. **Configuration Traefik** (`configure_traefik.sh`) :
   ```bash
   sudo ./configure_traefik.sh
   ```
   - Configure Traefik comme reverse proxy
   - Configure les certificats SSL avec Let's Encrypt
   - Déploie Portainer pour la gestion des conteneurs
   - Configure l'authentification basique
   - Démarre les services Docker

4. **Installation du serveur** (`install_server.sh`) :
   ```bash
   sudo ./install_server.sh
   ```
   - Installe les outils de monitoring (Prometheus, Node Exporter)
   - Vérifie la configuration globale
   - Teste l'accès aux services

> **Important** : Respectez cet ordre d'exécution pour assurer une installation correcte.
> Chaque script est conçu pour être exécuté indépendamment, mais dans un ordre spécifique
> pour assurer la cohérence de la configuration.

## 2. Installation Pas à Pas

### 2.1 Préparation de l'environnement

1. Sur le serveur, créez le dossier d'installation :
```bash
sudo mkdir -p /hebergement_serveur
sudo chown user:user /hebergement_serveur
sudo chmod 755 /hebergement_serveur
```

2. Copiez les fichiers nécessaires :
```bash
# Copiez les fichiers de configuration
scp -i "ssh/airquality_server_key" .env INSTALL_SERVEUR.md *.sh .ovhconfig user@192.168.1.134:/hebergement_serveur/

# Copiez le dossier scripts
scp -i "ssh/airquality_server_key" -r scripts user@192.168.1.134:/hebergement_serveur/
```

3. Ajustez les permissions :
```bash
cd /hebergement_serveur
sudo chown -R user:user .
sudo chmod -R 755 .
sudo chmod +x *.sh scripts/*.sh
```

### 2.2 Installation des Prérequis

1. Exécutez le script des prérequis :
```bash
sudo ./pre-requis.sh
```

2. Vérifiez l'installation :
```bash
# Vérifier Docker
docker --version
docker-compose --version

# Vérifier le pare-feu
sudo ufw status
```

### 2.3 Configuration DNS

1. Exécutez le script de configuration DNS :
```bash
sudo ./configure_ovh_dns.sh
```

2. Vérifiez la configuration :
```bash
# Vérifier la mise à jour DNS
cat /var/log/ovh_dns_update.log

# Vérifier la résolution DNS
dig +short airquality.iaproject.fr
```

### 2.4 Configuration Traefik

1. Exécutez le script de configuration Traefik :
```bash
sudo ./configure_traefik.sh
```

2. Vérifiez la configuration :
```bash
# Vérifier les conteneurs
docker ps

# Vérifier les logs
docker logs traefik

# Vérifier les certificats
ls -la /hebergement_serveur/certs/
```

### 2.5 Installation Finale

1. Exécutez le script d'installation :
```bash
sudo ./install_server.sh
```

2. Vérifiez l'installation complète :
```bash
# Vérifier les services de monitoring
sudo systemctl status prometheus
sudo systemctl status node-exporter

# Vérifier l'accès aux interfaces
curl -I https://traefik.airquality.iaproject.fr
curl -I https://portainer.airquality.iaproject.fr
```

## 3. Maintenance et Surveillance

### 3.1 Mise à jour des Services

Pour mettre à jour les services :

1. Arrêtez les conteneurs :
```bash
cd /hebergement_serveur/config/docker-compose
docker compose down
```

2. Mettez à jour les images :
```bash
docker compose pull
```

3. Redémarrez les conteneurs :
```bash
docker compose up -d
```

### 3.2 Sauvegarde

Pour sauvegarder les données importantes :

1. Sauvegardez les configurations :
```bash
tar -czf /hebergement_serveur/backup/config_$(date +%Y%m%d).tar.gz /hebergement_serveur/config/
```

2. Sauvegardez les données :
```bash
tar -czf /hebergement_serveur/backup/data_$(date +%Y%m%d).tar.gz /hebergement_serveur/data/
```

3. Sauvegardez les certificats :
```bash
tar -czf /hebergement_serveur/backup/certs_$(date +%Y%m%d).tar.gz /hebergement_serveur/certs/
```

### 3.3 Surveillance

Pour surveiller l'état du serveur :

1. Utilisez Portainer pour surveiller les conteneurs
2. Consultez les métriques dans Prometheus
3. Configurez des alertes dans Prometheus
4. Surveillez les logs dans Traefik

## 4. Dépannage

### 4.1 Problèmes Courants

1. **DNS non mis à jour** :
```bash
# Vérifier les logs de mise à jour DNS
cat /var/log/ovh_dns_update.log

# Vérifier la résolution DNS
dig +short airquality.iaproject.fr
```

2. **Problèmes de certificats SSL** :
```bash
# Vérifier les logs de Traefik
docker logs traefik

# Vérifier les certificats
ls -la /hebergement_serveur/certs/
```

3. **Services non accessibles** :
```bash
# Vérifier les conteneurs
docker ps

# Vérifier les logs
docker logs traefik
docker logs portainer
```

### 4.2 Réinitialisation

Pour réinitialiser une installation :

1. Arrêtez tous les services :
```bash
cd /hebergement_serveur/config/docker-compose
docker compose down
```

2. Nettoyez les configurations :
```bash
sudo rm -rf /hebergement_serveur/config/traefik/*
sudo rm -rf /hebergement_serveur/certs/*
```

3. Redémarrez les services :
```bash
sudo systemctl restart docker
```

4. Relancez l'installation dans l'ordre :
```bash
sudo ./pre-requis.sh
sudo ./configure_ovh_dns.sh
sudo ./configure_traefik.sh
sudo ./install_server.sh
```