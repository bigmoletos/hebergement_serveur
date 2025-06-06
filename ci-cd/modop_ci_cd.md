# Procédure CI/CD Jenkins – AirQuality

## 1.1 Création des jobs Jenkins

- **Tous les jobs Jenkins (dont `git-config`) sont créés dynamiquement via la configuration CasC dans le fichier :**
  - `hebergement_serveur/ci-cd/jenkins/casc/jenkins.yaml`
- Le job `git-config` est défini dans la section `jobs:` de ce fichier, à l'aide d'un bloc JobDSL Groovy.
- **Aucun fichier XML n'est utilisé pour la création des jobs.**

## 1.2 copie des fichiers sur le serveur

```bash
 scp -i "ssh/airquality_server_key" .env INSTALL_SERVEUR.md install_server.sh pre-requis.sh configure_ovh_dns.sh .ovhconfig debug_install.md user@192.168.1.134:/hebergement_serveur/ ;
 scp -i ".\ssh\airquality_server_key" -r "ansible/" user@192.168.1.134:/hebergement_serveur ;
 scp -i ".\ssh\airquality_server_key" -r "ci-cd/" user@192.168.1.134:/hebergement_serveur ;
 scp -i ".\ssh\airquality_server_key" -r "reverse-proxy/" user@192.168.1.134:/hebergement_serveur
```

## 2. Fichiers obsolètes

- Les fichiers suivants ne sont pas utilisés par Jenkins et peuvent être supprimés sans risque :
  - `hebergement_serveur/ci-cd/jenkins/casc/git-config.xml`
  - `hebergement_serveur/ci-cd/jenkins/casc/jobs/git-config.xml`
- Toute la configuration active est centralisée dans le YAML CasC.

## 3. Sécurité Git et safe.directory

- Pour éviter les erreurs de type `detected dubious ownership in repository`, le job `git-config` ajoute dynamiquement tous les sous-dossiers Jenkins comme `safe.directory` dans la configuration Git globale.
- Cette opération est automatisée dans le script shell du job `git-config`.

## 4. Maintenance et bonnes pratiques

- **Modifier uniquement le fichier `jenkins.yaml` pour toute évolution de la CI/CD.**
- Après modification, recharger la configuration CasC dans Jenkins pour appliquer les changements.
- Documenter toute modification majeure dans ce fichier de procédure.

---

*Dernière mise à jour : [12/05/2025]*
