# Configuration des Domaines airquality.iaproject.fr

Ce document détaille toutes les étapes nécessaires pour configurer les domaines `airquality.iaproject.fr` et `api.airquality.iaproject.fr`.

## 1. Configuration OVH DNS

### 1.1 Enregistrements DNS requis

- **airquality.iaproject.fr (A)**
  - Type: A
  - Valeur: IP_DU_SERVEUR
  - TTL: 3600

- **api.airquality.iaproject.fr (A)**
  - Type: A
  - Valeur: IP_DU_SERVEUR
  - TTL: 3600

- **www.airquality.iaproject.fr (CNAME)**
  - Type: CNAME
  - Valeur: airquality.iaproject.fr.
  - TTL: 3600

- **CAA Record**
  - Type: CAA
  - Valeur: 0 issue "letsencrypt.org"
  - TTL: 3600

### 1.2 Configuration via Ansible

```bash
# Configuration des variables d'environnement OVH
export OVH_ENDPOINT=ovh-eu
export OVH_APPLICATION_KEY=votre_application_key
export OVH_APPLICATION_SECRET=votre_application_secret
export OVH_CONSUMER_KEY=votre_consumer_key

# Exécution du playbook
ansible-playbook ansible/playbooks/configure_ovh_dns.yml
```

## 2. Configuration Traefik

### 2.1 Fichiers de Configuration

- **api.yml** : Configuration pour api.airquality.iaproject.fr
- **frontend.yml** : Configuration pour airquality.iaproject.fr

### 2.2 Vérification de la Configuration

```bash
# Vérifier la configuration Traefik
docker exec traefik traefik healthcheck

# Vérifier les logs Traefik
docker logs -f traefik
```

## 3. Configuration Freebox

### 3.1 Accès à l'Interface

1. Se connecter à l'interface Freebox (http://mafreebox.freebox.fr)
2. Aller dans "Paramètres de la Freebox" > "Mode Avancé" > "Gestion des ports"

### 3.2 Redirections de Ports Configurées

| Port Source (WAN) | Protocol | Port LAN | Description                           |
|------------------|----------|-----------|---------------------------------------|
| 8080-8090        | TCP      | 8080-8090 | Redirection vers le serveur ubuntu   |
| 443              | TCP      | 443       | Serveur ubuntu port https            |
| 22               | TCP      | 22        | Redirection pour SSH                  |
| 9000             | TCP      | 9000      | Redirection pour Portainer           |
| 80               | TCP      | 80        | Port https vers serveur ubuntu       |
| 2222             | TCP      | 2222      | Port pour Traefik                    |

### 3.3 Configuration dans l'Interface

![Configuration des ports Freebox](./images/freebox_port_config.png)

Pour chaque redirection :
1. Cliquer sur "Ajouter une redirection"
2. Sélectionner le protocole TCP
3. Définir le port WAN (externe)
4. Définir le port LAN (interne)
5. Sélectionner "SERVEUR" comme destination
6. Ajouter un commentaire descriptif
7. Activer la redirection

### 3.4 Vérification

Pour vérifier que les redirections sont actives :

```bash
# Test HTTPS
curl -vI https://airquality.iaproject.fr

# Test SSH
ssh -p 22 user@airquality.iaproject.fr

# Test Portainer
curl -vI https://portainer.iaproject.fr
```

### 3.5 Sécurité

- Limiter les redirections aux ports strictement nécessaires
- Utiliser des règles de pare-feu sur le serveur
- Surveiller régulièrement les logs d'accès
- Désactiver les redirections non utilisées

## 4. Vérification

### 4.1 Tests DNS

```bash
# Vérifier la résolution DNS
dig airquality.iaproject.fr
dig api.airquality.iaproject.fr
dig www.airquality.iaproject.fr

# Vérifier les enregistrements CAA
dig airquality.iaproject.fr CAA
```

### 4.2 Tests HTTPS

```bash
# Vérifier les certificats SSL
curl -vI https://airquality.iaproject.fr
curl -vI https://api.airquality.iaproject.fr
```

### 4.3 Tests d'Intégration

```bash
# Exécuter les tests d'intégration
export API_ENV=prod
python -m pytest tests/integration/test_api_sur_vm_test.py -v
```

## 5. Maintenance

### 5.1 Renouvellement des Certificats

Les certificats Let's Encrypt sont automatiquement renouvelés par Traefik.
Vérifier les logs pour s'assurer que le renouvellement fonctionne :

```bash
docker logs traefik | grep "Certificate renewal"
```

### 5.2 Surveillance

- Mettre en place une surveillance des certificats (expiration)
- Surveiller les logs Traefik pour les erreurs
- Vérifier régulièrement l'accessibilité des domaines

## 6. Résolution des Problèmes

### 6.1 Problèmes Courants

1. **Certificat non renouvelé**
   - Vérifier les logs Traefik
   - Vérifier l'accessibilité du port 80
   - Vérifier les enregistrements DNS

2. **DNS non résolu**
   - Vérifier la propagation DNS
   - Vérifier les enregistrements OVH
   - Vérifier le TTL

3. **Service inaccessible**
   - Vérifier les redirections Freebox
   - Vérifier les logs Traefik
   - Vérifier l'état des conteneurs Docker