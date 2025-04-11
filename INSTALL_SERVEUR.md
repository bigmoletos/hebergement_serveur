# Guide d'Installation et Configuration du Serveur

## 1. Configuration des clés SSH

### 1.1 Création des clés SSH

1. Sur votre machine locale (Windows), ouvrez PowerShell ou WSL et exécutez :
```bash
# Créer le dossier .ssh s'il n'existe pas
mkdir -p ~/.ssh
cd ~/.ssh

# Générer une nouvelle paire de clés (remplacez 'airquality_server' par le nom de votre choix)
ssh-keygen -t ed25519 -C "airquality_server" -f airquality_server_key

# Vérifier que les clés ont été créées
ls -la airquality_server_key*
```

2. Sécurisez les permissions des clés :
```bash
# Sous Windows (PowerShell)
icacls airquality_server_key /inheritance:r
icacls airquality_server_key /grant:r "$($env:USERNAME):(R)"

# Sous WSL/Linux
chmod 600 airquality_server_key
chmod 644 airquality_server_key.pub
```

### 1.2 Transfert de la clé publique vers le serveur

1. Copiez la clé publique sur le serveur :
```bash
# Méthode 1 : Utilisation de ssh-copy-id (si disponible)
ssh-copy-id -i ~/.ssh/airquality_server_key.pub user@192.168.1.134

# Méthode 2 : Copie manuelle
type ~/.ssh/airquality_server_key.pub | ssh user@192.168.1.134 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

### 1.3 Configuration de la connexion SSH

1. Créez ou modifiez le fichier `~/.ssh/config` sur votre machine locale :
```bash
# Sous Windows (PowerShell)
notepad $env:USERPROFILE\.ssh\config

# Sous WSL/Linux
nano ~/.ssh/config
```

2. Ajoutez la configuration suivante :
```config
Host airquality_server
    HostName 192.168.1.134
    User user
    IdentityFile ~/.ssh/airquality_server_key
    IdentitiesOnly yes
```

3. Testez la connexion :
```bash
# Connexion avec le nom d'hôte configuré
ssh airquality_server

# Ou avec l'adresse IP directement
ssh -i ~/.ssh/airquality_server_key user@192.168.1.134
```

### 1.4 Dépannage SSH

Si vous rencontrez des problèmes de connexion :

1. Vérifiez les permissions des clés :
```bash
# Sur votre machine locale
ls -la ~/.ssh/airquality_server_key*

# Sur le serveur
ls -la ~/.ssh/authorized_keys
```

2. Vérifiez le service SSH sur le serveur :
```bash
sudo systemctl status sshd
```

3. Consultez les logs SSH :
```bash
# Sur le serveur
sudo tail -f /var/log/auth.log
```

4. Testez la connexion avec le mode verbeux :
```bash
cd hebergement_serveur
ssh -i "ssh/airquality_server_key" user@192.168.1.134
```

## 2. Configuration du serveur SSH

### 2.1 Configuration de SSH pour les transferts de fichiers

1. Sur le serveur, modifiez la configuration SSH :
```bash
sudo nano /etc/ssh/sshd_config
```

2. Ajoutez ou modifiez les lignes suivantes :
```config
# Configuration de base
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentification
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Sécurité
X11Forwarding no
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 600
ClientAliveCountMax 3

# Logs
SyslogFacility AUTH
LogLevel INFO

# Utilisateurs autorisés
AllowUsers user

# Configuration pour SCP/SFTP
Subsystem sftp /usr/lib/openssh/sftp-server
```

3. Redémarrez le service SSH :
```bash
sudo systemctl restart sshd
```

4. Vérifiez les permissions des dossiers :
```bash
# Vérifiez les permissions du dossier home
ls -la /home/user/

# Vérifiez les permissions du dossier .ssh
ls -la /home/user/.ssh/

# Si nécessaire, corrigez les permissions
sudo chown -R user:user /home/user
sudo chmod 700 /home/user/.ssh
sudo chmod 600 /home/user/.ssh/authorized_keys
```

5. Testez la connexion SSH :
```bash
# Depuis votre machine locale
ssh -v -i ~/.ssh/airquality_server_key user@192.168.1.134
```

## 3. Prérequis

### 3.1 Installation des prérequis

1. Sur le serveur, créez le dossier d'installation avec les bonnes permissions :
```bash
sudo mkdir -p /hebergement_serveur
sudo chown user:user /hebergement_serveur
sudo chmod 755 /hebergement_serveur
```

2. Depuis votre machine locale, copiez les fichiers nécessaires sur le serveur :
```bash
# Copiez les fichiers de configuration
scp -i "ssh/airquality_server_key" .env INSTALL_SERVEUR.md install_server.sh pre-requis.sh configure_ovh_dns.sh .ovhconfig debug_install.md user@192.168.1.134:/hebergement_serveur/

# Copiez le dossier scripts
scp -i "ssh/airquality_server_key" -r scripts user@192.168.1.134:/hebergement_serveur/
```

3. Sur le serveur, vérifiez et ajustez les permissions :

```bash
cd /hebergement_serveur
sudo chown -R user:user .
sudo chmod -R 755 .
sudo chmod +x *.sh scripts/*.sh
```

4. Lancez le script des prérequis :
```bash
sudo ./pre-requis.sh
```

# ou en 1 ligne

```bash
scp -i "ssh/airquality_server_key" .env INSTALL_SERVEUR.md install_server.sh pre-requis.sh configure_ovh_dns.sh .ovhconfig debug_install.md user@192.168.1.134:/hebergement_serveur/ ;  scp -i "ssh/airquality_server_key" -r scripts user@192.168.1.134:/hebergement_serveur/

sudo systemctl restart sshd && sudo chmod +x *.sh scripts/*.sh && sudo ./pre-requis.sh

```

Le script va :
- Mettre à jour le système
- Installer Docker et Docker Compose
- Configurer le pare-feu
- Sécuriser SSH
- Créer la structure de répertoires suivante :
  ```
  /hebergement_serveur/
  ├── config/              # Configurations
  │   ├── traefik/        # Configuration de Traefik
  │   ├── docker-compose/ # Fichiers docker-compose
  │   └── env/           # Variables d'environnement
  ├── data/               # Données persistantes
  │   ├── jenkins/
  │   ├── portainer/
  │   ├── api/
  │   └── monitoring/
  ├── logs/               # Logs centralisés
  ├── certs/              # Certificats SSL
  └── scripts/            # Scripts de maintenance
  ```

7. Vérifiez l'installation :
```bash
# Vérifier Docker
docker --version
docker-compose --version

# Vérifier le pare-feu
sudo ufw status

# Vérifier SSH
sudo systemctl status sshd
```

### 3.2 Configuration de l'authentification SSH

La clé SSH doit être dans le répertoire standard `