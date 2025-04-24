# Guide de Gestion des Secrets avec HashiCorp Vault

## Installation de Vault

### 1. Déploiement avec Docker

```yaml
# docker-compose.vault.yml
services:
  vault:
    image: vault:1.13
    container_name: vault
    restart: unless-stopped
    cap_add:
      - IPC_LOCK
    environment:
      - VAULT_ADDR=https://0.0.0.0:8200
      - VAULT_API_ADDR=https://vault.iaproject.fr
    volumes:
      - ./config:/vault/config
      - ./data:/vault/data
      - ./logs:/vault/logs
    ports:
      - "8200:8200"
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.vault.rule=Host(`vault.iaproject.fr`)"
      - "traefik.http.routers.vault.entrypoints=websecure"
      - "traefik.http.routers.vault.tls.certresolver=letsencrypt"
      - "traefik.http.services.vault.loadbalancer.server.port=8200"
```

### 2. Configuration de Base

```hcl
# config/vault.hcl
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 0
  tls_cert_file = "/vault/config/cert.pem"
  tls_key_file  = "/vault/config/key.pem"
}

api_addr = "https://vault.iaproject.fr"
ui = true
```

## Initialisation et Configuration

### 1. Initialisation de Vault

```bash
# Initialisation
vault operator init

# Résultat à sauvegarder de manière sécurisée
Unseal Key 1: xxxxx
Unseal Key 2: xxxxx
Unseal Key 3: xxxxx
Unseal Key 4: xxxxx
Unseal Key 5: xxxxx

Initial Root Token: xxxxx
```

### 2. Déverrouillage (Unseal)

```bash
# À faire avec 3 clés différentes
vault operator unseal <Unseal Key 1>
vault operator unseal <Unseal Key 2>
vault operator unseal <Unseal Key 3>
```

## Structure des Secrets

### 1. Création des Chemins

```bash
# Activation du moteur KV version 2
vault secrets enable -version=2 kv

# Création des chemins
vault kv put secret/shared/docker \
    username="dockerhub_user" \
    password="dockerhub_password"

vault kv put secret/shared/github \
    token="github_token" \
    ssh_key="@/path/to/ssh_key"

vault kv put secret/shared/gitlab \
    token="gitlab_token" \
    registry_token="registry_token"

vault kv put secret/shared/jenkins \
    admin_password="jenkins_admin_pwd" \
    api_token="jenkins_api_token"

vault kv put secret/shared/ovh \
    application_key="app_key" \
    application_secret="app_secret" \
    consumer_key="consumer_key"

vault kv put secret/shared/traefik \
    acme_email="admin@iaproject.fr" \
    dashboard_password="dashboard_pwd"
```

### 2. Politiques d'Accès

```hcl
# policies/jenkins.hcl
path "secret/data/shared/docker" {
  capabilities = ["read"]
}

path "secret/data/shared/github" {
  capabilities = ["read"]
}

path "secret/data/applications/+/database" {
  capabilities = ["read", "update"]
}
```

## Intégration avec les Services

### 1. Jenkins

```groovy
// Jenkinsfile
pipeline {
    environment {
        VAULT_ADDR = 'https://vault.iaproject.fr'
        VAULT_TOKEN = credentials('vault-token')
    }

    stages {
        stage('Get Secrets') {
            steps {
                script {
                    def dockerCreds = vault.read('secret/shared/docker')
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-registry',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        // Utilisation des credentials
                    }
                }
            }
        }
    }
}
```

### 2. Ansible

```yaml
# playbook.yml
- name: Deploy with secrets
  hosts: all
  vars:
    docker_creds: "{{ lookup('community.hashi_vault.vault_read', 'secret/shared/docker') }}"
    github_token: "{{ lookup('community.hashi_vault.vault_read', 'secret/shared/github').data.token }}"

  tasks:
    - name: Login to Docker
      docker_login:
        username: "{{ docker_creds.data.username }}"
        password: "{{ docker_creds.data.password }}"
```

### 3. Traefik

```yaml
# traefik.yml
certificatesResolvers:
  letsencrypt:
    acme:
      email: "{{ lookup('community.hashi_vault.vault_read', 'secret/shared/traefik').data.acme_email }}"
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web
```

### 4. Applications Python

```python
import hvac

client = hvac.Client(
    url='https://vault.iaproject.fr',
    token='xxx'
)

# Lecture des secrets
db_creds = client.secrets.kv.v2.read_secret_version(
    path='applications/airquality/database'
)
```

## Rotation des Secrets

### 1. Rotation Automatique

```yaml
# vault/rotate_secrets.yml
- name: Rotate Application Secrets
  hosts: localhost
  tasks:
    - name: Generate new password
      command: openssl rand -base64 32
      register: new_password

    - name: Update secret in Vault
      community.hashi_vault.vault_write:
        path: secret/shared/jenkins
        data:
          admin_password: "{{ new_password.stdout }}"

    - name: Update Jenkins configuration
      jenkins_script:
        script: |
          jenkins.model.Jenkins.instance.setSecurityRealm(
            new hudson.security.HudsonPrivateSecurityRealm(false)
          )
          def user = jenkins.model.Jenkins.instance.getSecurityRealm().createAccount(
            "admin", "{{ new_password.stdout }}"
          )
```

### 2. Audit des Accès

```bash
# Activation de l'audit
vault audit enable file file_path=/vault/logs/audit.log

# Consultation des logs
tail -f /vault/logs/audit.log | jq
```

## Sécurité et Bonnes Pratiques

1. **Gestion des Tokens**
   - Utilisation de tokens avec TTL limité
   - Renouvellement automatique des tokens
   - Révocation immédiate en cas de compromission

2. **Backup et Restauration**
   ```bash
   # Backup
   vault operator raft snapshot save snapshot.gz

   # Restore
   vault operator raft snapshot restore snapshot.gz
   ```

3. **Monitoring**
   ```bash
   # Métriques Prometheus
   vault write sys/metrics/prometheus format=prometheus
   ```

## Troubleshooting

1. **Vérification du Statut**
   ```bash
   vault status
   vault operator raft list-peers
   ```

2. **Logs**
   ```bash
   tail -f /vault/logs/vault.log
   ```

3. **Déblocage d'Urgence**
   ```bash
   # En cas de perte d'accès
   vault operator generate-root -init
   vault operator generate-root
   vault operator generate-root -decode=xxx
   ```