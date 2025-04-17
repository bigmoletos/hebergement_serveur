# Journal de Débogage de l'Installation

## 1. Problèmes de Configuration SSH

### 1.1 Session SSH qui se ferme immédiatement
**Symptôme** :
```
avril 11 12:17:20 worker1 sshd[72339]: Accepted publickey for user from 192.168.1.43 port 64862
avril 11 12:17:20 worker1 sshd[72339]: pam_unix(sshd:session): session opened for user user
avril 11 12:17:20 worker1 sshd[72339]: pam_unix(sshd:session): session closed for user user
```

**Causes possibles** :
1. Configuration SSH trop restrictive
2. Problèmes de permissions
3. Configuration PAM incorrecte

**Solutions appliquées** :
1. Modification de `sshd_config` :
   ```config
   MaxSessions 10
   ClientAliveInterval 600
   ClientAliveCountMax 3
   ```
2. Vérification des permissions :
   ```bash
   sudo chown -R user:user /home/user
   sudo chmod 700 /home/user/.ssh
   sudo chmod 600 /home/user/.ssh/authorized_keys
   ```

### 1.2 Erreur de Permission Denied lors du SCP
**Symptôme** :
```
scp: /hebergement_serveur/scripts/load_env.sh: Permission denied
```

**Causes possibles** :
1. Permissions incorrectes sur le dossier `/hebergement_serveur`
2. Problème de propriétaire du dossier

**Solutions appliquées** :
1. Correction des permissions :
   ```bash
   sudo chown -R user:user /hebergement_serveur
   sudo chmod -R 755 /hebergement_serveur
   ```
2. Création du dossier scripts :
   ```bash
   sudo mkdir -p /hebergement_serveur/scripts
   sudo chown user:user /hebergement_serveur/scripts
   sudo chmod 755 /hebergement_serveur/scripts
   ```

## 2. Problèmes de Configuration des Clés SSH

### 2.1 Configuration des HostKeys
**Symptôme** :
Configuration initiale avec des clés non optimales

**Solutions appliquées** :
1. Utilisation des trois types de clés :
   ```config
   HostKey /etc/ssh/ssh_host_rsa_key
   HostKey /etc/ssh/ssh_host_ecdsa_key
   HostKey /etc/ssh/ssh_host_ed25519_key
   ```

### 2.2 Problème avec AllowUsers
**Symptôme** :
Configuration incorrecte avec `AllowUsers user root`

**Solutions appliquées** :
1. Correction de la configuration :
   ```config
   AllowUsers user
   ```
2. Vérification de la cohérence avec `PermitRootLogin no`

## 3. Vérifications de Sécurité

### 3.1 Liste des vérifications à effectuer
1. **Permissions des dossiers** :
   ```bash
   ls -la /home/user/
   ls -la /home/user/.ssh/
   ls -la /hebergement_serveur/
   ```

2. **Configuration SSH** :
   ```bash
   sudo sshd -t
   sudo systemctl status sshd
   ```

3. **Logs système** :
   ```bash
   sudo tail -f /var/log/auth.log
   sudo journalctl -u ssh -f
   ```

### 3.2 Commandes de débogage
1. **Test de connexion SSH** :
   ```bash
   ssh -vvv -i ~/.ssh/airquality_server_key user@192.168.1.134
   ```

2. **Test de transfert SCP** :
   ```bash
   scp -v -i ~/.ssh/airquality_server_key test_file user@192.168.1.134:/hebergement_serveur/
   ```

3. **Vérification des services** :
   ```bash
   sudo systemctl status sshd
   sudo systemctl status fail2ban
   sudo ufw status
   ```

## 4. Procédure de Récupération

### 4.1 En cas de problème de connexion SSH
1. Se connecter en console physique ou via IPMI
2. Restaurer la configuration SSH :
   ```bash
   sudo cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d) /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

### 4.2 En cas de problème de permissions
1. Corriger les permissions :
   ```bash
   sudo chown -R user:user /hebergement_serveur
   sudo chmod -R 755 /hebergement_serveur
   ```

### 4.3 En cas de problème de configuration
1. Vérifier la configuration :
   ```bash
   sudo sshd -t
   ```
2. Si invalide, restaurer la sauvegarde :
   ```bash
   sudo cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d) /etc/ssh/sshd_config
   ```

## 5. Bonnes Pratiques à Suivre

### 5.1 Avant toute modification
1. Toujours sauvegarder la configuration actuelle
2. Tester la configuration avant de l'appliquer
3. Avoir un plan de rollback

### 5.2 Pendant l'installation
1. Vérifier les logs en temps réel
2. Tester chaque étape avant de passer à la suivante
3. Documenter les erreurs et solutions

### 5.3 Après l'installation
1. Vérifier que tous les services fonctionnent
2. Tester les accès SSH et SCP
3. Vérifier les permissions des dossiers
4. Sauvegarder la configuration finale

## 6. Configuration SFTP

### 6.1 Importance de la configuration SFTP
**Configuration** :
```config
Subsystem sftp /usr/lib/openssh/sftp-server
```

**Pourquoi c'est important** :
1. **Fonctionnalités SFTP** :
   - Transfert de fichiers sécurisé
   - Navigation dans les dossiers
   - Gestion des permissions
   - Meilleure fiabilité que SCP

2. **Pourquoi ça marchait sans** :
   - Configuration par défaut dans la plupart des distributions
   - Chemin `/usr/lib/openssh/sftp-server` souvent préconfiguré

3. **Avantages de l'ajouter explicitement** :
   - Documentation claire de la configuration
   - Possibilité de personnalisation
   - Meilleure maintenabilité

4. **Différences SCP vs SFTP** :
   - **SCP** :
     - Simple copie de fichiers
     - Moins de fonctionnalités
     - Plus rapide pour les petits fichiers

   - **SFTP** :
     - Interface complète de gestion de fichiers
     - Meilleure gestion des erreurs
     - Support des fichiers volumineux
     - Gestion des permissions

### 6.2 Vérification de SFTP
1. **Test de connexion SFTP** :
   ```bash
   sftp -i ~/.ssh/airquality_server_key user@192.168.1.134
   ```

2. **Commandes SFTP utiles** :
   ```bash
   # Navigation
   ls
   cd dossier
   pwd

   # Transfert
   put fichier_local
   get fichier_distant

   # Gestion des permissions
   chmod 755 fichier
   chown user:group fichier
   ```

## 2025-04-13 : Problèmes avec ddclient

### Problème 1 : Erreur de chemin lors de la copie de configuration
```bash
Error: cp: cannot stat 'hebergement_serveur/scripts/ddclient.conf': No such file or directory
```

**Solution** :
1. Se placer dans le bon répertoire
2. Utiliser le chemin relatif correct :
```bash
cd /hebergement_serveur
sudo cp scripts/ddclient.conf /etc/ddclient.conf
```

### Problème 2 : Permissions incorrectes
**Symptômes** :
- Fichiers .sh avec permissions 777 (trop permissives)
- ddclient.conf avec permissions 644 (trop permissives pour les mots de passe)

**Solution** :
1. Ajustement des permissions des fichiers de configuration :
```bash
sudo chmod 600 /etc/ddclient.conf
sudo chown root:root /etc/ddclient.conf
```

2. Ajustement des permissions des scripts :
```bash
sudo chmod 644 scripts/*.py
sudo chmod 644 scripts/*.conf
sudo chmod 755 scripts/*.sh
```

### Problème 3 : Erreur d'authentification ddclient
**Symptômes** :
```
FAILED: {"class":"Client::Unauthorized","message":"..."}
```

**Solution** :
1. Configuration correcte dans `/etc/ddclient.conf` :
```conf
# Configuration générale
daemon=300
syslog=yes
pid=/var/run/ddclient.pid
ssl=yes

# Configuration OVH
protocol=dyndns2
use=web
server=www.ovh.com
login=iaproject.fr-identdns
password='+-*/2000Dns/*-+'
zone=iaproject.fr
airquality.iaproject.fr
```

2. Redémarrage du service :
```bash
sudo systemctl restart ddclient
```

### Vérification
```bash
# Test de la configuration
sudo ddclient -daemon=0 -debug -verbose -noquiet

# Vérification du service
sudo systemctl status ddclient

# Surveillance des logs
sudo tail -f /var/log/ddclient.log
sudo journalctl -u ddclient -f
```

## 2025-04-13 : Mise à jour du noyau Linux

### Procédure complète de mise à jour du noyau

1. **Vérification des noyaux installés** :
   ```bash
   dpkg -l | grep linux-image
   ```

2. **Installation/réinstallation du nouveau noyau** :
   ```bash
   sudo apt-get install --reinstall linux-image-5.15.0-138-generic linux-headers-5.15.0-138-generic
   ```

3. **Sauvegarde de la configuration GRUB** :
   ```bash
   sudo cp /etc/default/grub /etc/default/grub.backup
   ```

4. **Réinstallation de GRUB** :
   ```bash
   sudo grub-install /dev/sda
   sudo apt install --reinstall linux-image-5.15.0-138-generic
   sudo apt-get install --reinstall grub-pc
   sudo grub-install /dev/sda
   sudo update-grub
   ```

5. **Identification du menu GRUB** :
   ```bash
   grep -A1 menuentry /boot/grub/grub.cfg
   ```
   Notez le nom complet de l'entrée souhaitée, par exemple :
   ```
   menuentry 'Ubuntu, with Linux 5.15.0-138-generic' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-5.15.0-138-generic-advanced-06206d3c-1dd2-4fb6-bb96-1d15d9e53bbd'
   ```

6. **Configuration de GRUB** :
   ```bash
   sudo nano /etc/default/grub
   ```
   Modifiez la ligne GRUB_DEFAULT avec le nom complet, par exemple :
   ```bash
   GRUB_DEFAULT="gnulinux-advanced-06206d3c-1dd2-4fb6-bb96-1d15d9e53bbd>gnulinux-5.15.0-138-generic-advanced-06206d3c-1dd2-4fb6-bb96-1d15d9e53bbd"
   ```

7. **Application des changements** :
   ```bash
   sudo update-grub
   sudo reboot
   ```

8. **Vérification** :
   ```bash
   uname -r
   ```
   Devrait afficher : `5.15.0-138-generic`

### Points importants
- Toujours sauvegarder la configuration GRUB avant modification
- Utiliser le nom complet de l'entrée GRUB
- Vérifier la version du noyau après redémarrage
- En cas de problème, restaurer la sauvegarde de GRUB