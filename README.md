# Gestion de l'Hébergement OVH

Ce projet contient les configurations et les procédures pour gérer l'hébergement web sur OVH, incluant la gestion des certificats SSL et des clés SSH.

## Structure du Projet

```
hebergement_serveur/
├── ssl/                # Gestion des certificats SSL
├── ssl2/              # Backup des certificats SSL
└── ssh/               # Gestion des clés SSH
```

## Prérequis

- Git Bash installé sur Windows
- Un compte OVH avec accès au manager
- Un hébergement web OVH

## 1. Gestion des Certificats SSL

### 1.1 Génération de la clé privée
```bash
# Dans Git Bash, générer la clé privée RSA
openssl genrsa -out ssl/private.key 2048
```

### 1.2 Génération de la demande de certificat (CSR)
```bash
# Dans Git Bash, générer le CSR en utilisant la clé privée
openssl req -new -key ssl/private.key -out ssl/request.csr
```

Lors de la génération du CSR, fournir les informations suivantes :
- Common Name (CN) : ${DYNDNS_DOMAIN}
- Country Name : FR
- State/Province : votre région
- Locality : votre ville
- Organization Name : nom de votre entreprise ou votre nom
- Organizational Unit : département ou laisser vide avec '.'
- Email Address : ${NGINX_SSL_EMAIL}
- Challenge password : laisser vide (Enter)
- Optional company name : laisser vide (Enter)

### 1.3 Installation sur OVH

1. Connectez-vous à votre espace client OVH
2. Accédez à la section hébergement web
3. Sélectionnez l'option pour installer un certificat SSL
4. Dans le formulaire à 3 champs :
   - Premier champ : contenu du fichier `request.csr`
   - Deuxième champ : contenu du fichier `private.key`
   - Troisième champ : laisser vide (sera fourni par OVH)

## 2. Gestion des Clés SSH

### 2.1 Génération des clés SSH
```bash
# Dans Git Bash, générer une paire de clés SSH
ssh-keygen -t rsa -b 4096 -C "${NGINX_SSL_EMAIL}" -f ssh/airquality_server_key
```

### 2.2 Installation de la clé publique sur OVH
1. Copier le contenu du fichier `id_rsa.pub`
2. Dans le manager OVH, accédez à la section SSH
3. Coller la clé publique dans le champ approprié

## Commandes Utiles

### Vérification des certificats
```bash
# Vérifier le contenu du CSR
openssl req -text -noout -verify -in request.csr

# Vérifier la clé privée
openssl rsa -check -in private.key
```

### Vérification des clés SSH
```bash
# Vérifier la clé privée SSH
ssh-keygen -l -f id_rsa

# Vérifier la clé publique SSH
ssh-keygen -l -f id_rsa.pub
```

## Sécurité et Bonnes Pratiques

- Conservez précieusement vos clés privées
- Ne partagez jamais vos clés privées
- Faites des sauvegardes sécurisées des fichiers
- Documentez les dates d'expiration des certificats
- Utilisez des mots de passe forts pour protéger vos clés

## Maintenance

### Renouvellement des certificats SSL
1. Générer une nouvelle clé privée
2. Créer un nouveau CSR
3. Suivre la procédure d'installation sur OVH
4. Mettre à jour les certificats sur le serveur

### Rotation des clés SSH
1. Générer une nouvelle paire de clés
2. Installer la nouvelle clé publique sur OVH
3. Tester la connexion avec la nouvelle clé
4. Supprimer l'ancienne clé une fois la nouvelle validée

## Dépannage

### Problèmes courants avec SSL
- Erreur de format de CSR : vérifier le contenu avec `openssl req -text -noout -verify -in request.csr`
- Problème de clé privée : vérifier avec `openssl rsa -check -in private.key`
- Certificat expiré : suivre la procédure de renouvellement

### Problèmes courants avec SSH
- Connexion refusée : vérifier la clé publique sur OVH
- Permission denied : vérifier les permissions des fichiers de clés
- Host key verification failed : ajouter l'option `-o StrictHostKeyChecking=no` à la commande SSH

## Contact

Pour toute question ou assistance, contacter le support OVH ou consulter la documentation officielle.

## Automatisation et Scripts

### Script de vérification des certificats
```python
#!/usr/bin/env python3
import subprocess
import datetime
import logging
import os

# Configuration du logger
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filename='ssl_check.log'
)

def verify_ssl_certificate(cert_path):
    try:
        result = subprocess.run(
            ['openssl', 'x509', '-in', cert_path, '-noout', '-enddate'],
            capture_output=True,
            text=True
        )
        expiry_date = result.stdout.split('=')[1].strip()
        logging.info(f"Date d'expiration du certificat : {expiry_date}")
        return expiry_date
    except Exception as e:
        logging.error(f"Erreur lors de la vérification du certificat : {str(e)}")
        return None

def check_certificates():
    ssl_dir = os.path.join(os.path.dirname(__file__), 'ssl')
    for cert_file in os.listdir(ssl_dir):
        if cert_file.endswith('.crt'):
            verify_ssl_certificate(os.path.join(ssl_dir, cert_file))
```

### Monitoring et Alertes

#### Configuration des alertes
- Mise en place d'alertes email pour l'expiration des certificats
- Surveillance des performances du serveur
- Monitoring des tentatives de connexion SSH

#### Exemple de configuration de monitoring
```yaml
monitoring:
  ssl:
    check_interval: 24h
    alert_before_expiry: 30d
  ssh:
    max_failed_attempts: 5
    block_duration: 1h
```

## Sauvegarde et Restauration

### Procédure de sauvegarde
1. Sauvegarde automatique quotidienne des certificats
2. Export régulier des configurations SSH
3. Stockage sécurisé des sauvegardes sur un système distant

### Script de sauvegarde
```python
#!/usr/bin/env python3
import shutil
import os
from datetime import datetime
import logging

# Configuration du logger
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filename='backup.log'
)

def backup_certificates():
    try:
        backup_dir = os.path.join(os.path.dirname(__file__), f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        os.makedirs(backup_dir, exist_ok=True)

        # Sauvegarde des certificats SSL
        ssl_dir = os.path.join(os.path.dirname(__file__), 'ssl')
        for file in os.listdir(ssl_dir):
            if file.endswith(('.key', '.csr', '.crt', '.pem')):
                shutil.copy2(os.path.join(ssl_dir, file), os.path.join(backup_dir, file))

        # Sauvegarde des clés SSH
        ssh_dir = os.path.join(os.path.dirname(__file__), 'ssh')
        for file in os.listdir(ssh_dir):
            if file.endswith(('_key', '.pub')):
                shutil.copy2(os.path.join(ssh_dir, file), os.path.join(backup_dir, file))

        logging.info(f"Sauvegarde créée avec succès dans {backup_dir}")
    except Exception as e:
        logging.error(f"Erreur lors de la sauvegarde : {str(e)}")
```

## Conformité et Sécurité

### Règles de conformité
- Respect du RGPD pour les données personnelles
- Conformité aux normes de sécurité PCI DSS si applicable
- Documentation des procédures de sécurité

### Audit de sécurité
- Vérification régulière des permissions
- Analyse des logs de connexion
- Tests de pénétration périodiques

## Intégration Continue

### Pipeline CI/CD
```yaml
pipeline:
  stages:
    - verify_ssl
    - backup_configs
    - deploy_changes

  actions:
    verify_ssl:
      script: ./scripts/verify_ssl.py
      on_failure: notify_admin

    backup_configs:
      script: ./scripts/backup.py
      schedule: daily
```

## Ressources Additionnelles

### Documentation Officielle
- [Documentation OVH](https://docs.ovh.com)
- [Guide SSL/TLS](https://docs.ovh.com/fr/ssl/)
- [Sécurité SSH](https://docs.ovh.com/fr/dedicated/ssh-introduction/)

### Outils Recommandés
- Certbot pour la gestion automatique des certificats Let's Encrypt
- Fail2ban pour la sécurité SSH
- Ansible pour l'automatisation des déploiements

## Versions et Mises à Jour

### Journal des modifications
- v1.0.0 : Configuration initiale
- v1.1.0 : Ajout de l'automatisation
- v1.2.0 : Intégration du monitoring

### Compatibilité
- Python 3.8+
- OpenSSL 1.1.1+
- Git Bash (Windows) ou Terminal (Linux/MacOS)

## Support et Contribution

### Comment contribuer
1. Forker le projet
2. Créer une branche pour votre fonctionnalité
3. Soumettre une pull request

### Support communautaire
- Forum OVH
- Canal Slack du projet
- Issues GitHub