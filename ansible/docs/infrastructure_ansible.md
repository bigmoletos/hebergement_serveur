# Infrastructure Ansible pour Multi-Applications

## Configuration DNS
pour cela on peux lancer depuis le serveur le script

```bash
# 1. Se placer dans le bon répertoire
cd /hebergement_serveur

# 2. Vérifier que les variables d'environnement sont définies
cat .env | grep OVH
# Devrait afficher :
# OVH_APPLICATION_KEY=xxx
# OVH_APPLICATION_SECRET=xxx
# OVH_CONSUMER_KEY=xxx
# OVH_DNS_ZONE=iaproject.fr

# 3. Lancer le script
./configure_ovh_dns.sh

# Vérifier que les zones ont été créées
for subdomain in airquality prediction-vent api-meteo portainer jenkins vault traefik grafana prometheus; do
    dig ${subdomain}.iaproject.fr
done

```

### On devrait avoir dans les DNS ZONE OVH les Applications suivantes:
| Type | Sous-domaine     | Destination | Description                    |
|------|------------------|-------------|--------------------------------|
| A    | airquality      | IP_SERVEUR  | Application qualité de l'air   |
| A    | prediction-vent | IP_SERVEUR  | Service de prédiction du vent |
| A    | api-meteo      | IP_SERVEUR  | API météo                     |

### Services de Gestion
| Type | Sous-domaine    | Destination | Description                    |
|------|----------------|-------------|--------------------------------|
| A    | portainer     | IP_SERVEUR  | Interface de gestion Docker    |
| A    | jenkins       | IP_SERVEUR  | Serveur CI/CD                  |
| A    | vault         | IP_SERVEUR  | Gestionnaire de secrets        |
| A    | traefik       | IP_SERVEUR  | Dashboard Traefik             |

### Monitoring
| Type | Sous-domaine    | Destination | Description                    |
|------|----------------|-------------|--------------------------------|
| A    | grafana       | IP_SERVEUR  | Visualisation des métriques    |
| A    | prometheus    | IP_SERVEUR  | Collecte des métriques         |

## Architecture Globale

```
/opt/
├── applications/          # Applications conteneurisées
│   ├── airquality/       # Qualité de l'air
│   │   ├── config/      # Configuration de l'application
│   │   ├── data/        # Données persistantes
│   │   ├── logs/        # Logs applicatifs
│   │   ├── docker/      # Fichiers Docker
│   │   └── scripts/     # Scripts utilitaires
│   ├── prediction-vent/  # Prédiction du vent
│   └── api-meteo/       # API Météo
├── traefik/             # Reverse Proxy
│   ├── config/         # Configuration Traefik
│   ├── certs/         # Certificats SSL
│   ├── logs/          # Logs d'accès
│   └── rules/         # Règles dynamiques
├── monitoring/          # Supervision
│   ├── prometheus/     # Métriques
│   ├── grafana/       # Visualisation
│   ├── alertmanager/  # Gestion des alertes
│   └── logs/          # Centralisation des logs
├── vault/              # Gestion des secrets
│   ├── config/        # Configuration Vault
│   ├── data/          # Données chiffrées
│   └── logs/          # Audit logs
└── ci-cd/              # Intégration Continue
    ├── jenkins/       # Service Jenkins
    ├── scripts/       # Scripts CI/CD
    ├── config/        # Configuration
    └── logs/          # Logs des builds
```

## Structure des Playbooks

```
ansible/
├── playbooks/
│   ├── main.yml                    # Playbook principal
│   ├── setup_apps_structure.yml    # Configuration infrastructure
│   ├── vault_setup.yml            # Installation Vault
│   └── applications/
│       ├── airquality/
│       │   └── deploy.yml         # Déploiement qualité air
│       ├── prediction-vent/
│       └── api-meteo/
├── templates/
│   ├── docker-compose.yml.j2      # Template Docker Compose
│   ├── vault.hcl.j2              # Config Vault
│   └── traefik.yml.j2            # Config Traefik
├── inventories/
│   ├── production/
│   │   ├── hosts.yml             # Hôtes production
│   │   └── group_vars/           # Variables par groupe
│   └── staging/
└── docs/
    ├── infrastructure_ansible.md  # Documentation générale
    └── gestion_secret_vault.md   # Guide Vault
```

## Flux de Déploiement

1. **Préparation Infrastructure**
   ```bash
   # Installation de Vault
   ansible-playbook playbooks/vault_setup.yml

   # Configuration de base
   ansible-playbook playbooks/setup_apps_structure.yml
   ```

2. **Configuration des Applications**
   ```bash
   # Déploiement complet
   ansible-playbook playbooks/main.yml

   # Déploiement spécifique
   ansible-playbook playbooks/main.yml --tags airquality
   ```

## Intégration des Services

### 1. Traefik (Reverse Proxy)
- Gestion SSL automatique avec Let's Encrypt
- Routing basé sur les labels Docker
- Monitoring et métriques

### 2. Vault (Gestion des Secrets)
- Authentification centralisée
- Rotation automatique des secrets
- Audit et traçabilité

### 3. Monitoring
- Prometheus pour les métriques
- Grafana pour la visualisation
- Alertmanager pour les notifications

### 4. CI/CD
- Jenkins pour l'automatisation
- Intégration avec Vault pour les secrets
- Pipeline as Code

## Variables d'Environnement

```bash
# Vault
export VAULT_ADDR='https://vault.iaproject.fr'
export VAULT_TOKEN='<token>'

# OVH DNS
export OVH_DNS_ZONE='iaproject.fr'
export OVH_DNS_SUBDOMAIN='<subdomain>'

# Docker Registry
export DOCKER_REGISTRY='registry.iaproject.fr'
```

## Sécurité et Bonnes Pratiques

1. **Gestion des Secrets**
   - Utilisation systématique de Vault
   - Pas de secrets en clair dans les playbooks
   - Rotation régulière des credentials

2. **Réseau**
   - Isolation des réseaux Docker
   - TLS pour toutes les communications
   - Restriction des accès par IP

3. **Monitoring**
   - Surveillance des accès
   - Alertes sur les événements critiques
   - Rétention des logs

## Maintenance

1. **Sauvegardes**
   - Vault (données et configuration)
   - Certificats SSL
   - Données applicatives

2. **Mises à jour**
   - Planification des mises à jour
   - Tests en environnement staging
   - Procédures de rollback

3. **Documentation**
   - Mise à jour régulière
   - Procédures d'urgence
   - Guides de dépannage

## Environnements

1. **Production**
   ```yaml
   environment: production
   domain: iaproject.fr
   monitoring: enabled
   backup: enabled
   ```

2. **Staging**
   ```yaml
   environment: staging
   domain: staging.iaproject.fr
   monitoring: enabled
   backup: disabled
   ```

## Commandes Utiles

```bash
# Vérification de la configuration
ansible-playbook main.yml --check

# Déploiement avec variables spécifiques
ansible-playbook main.yml --extra-vars "env=production"

# Déploiement d'une application spécifique
ansible-playbook main.yml --tags airquality

# Rotation des secrets
ansible-playbook vault/rotate_secrets.yml
```

## Troubleshooting

1. **Logs**
   ```bash
   # Logs Traefik
   docker logs traefik

   # Logs Vault
   docker logs vault

   # Logs applicatifs
   docker logs airquality
   ```

2. **Vérifications**
   ```bash
   # État des services
   docker ps

   # Réseaux Docker
   docker network ls

   # Certificats SSL
   docker exec traefik cat /etc/traefik/acme.json
   ```