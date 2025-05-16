// =====================================================
// Pipeline JobDSL : gestion de la configuration d'hébergement
// - Surveille le dépôt GitHub d'hébergement
// - Applique les mises à jour de configuration nécessaires
// Objectif : Ce pipeline est conçu pour gérer la configuration de l'infrastructure d'hébergement elle-même. Il surveille le dépôt hebergement_serveur sur GitHub et, en cas de changement, exécute le Jenkinsfile.hebergement.
// Déclenchement :
// Il est configuré pour se déclencher sur un githubPush grâce à pipelineTriggers { triggers { githubPush() } }.
// Utilisation / Impact :
// Ce job exécute le hebergement_serveur/ci-cd/jenkins/Jenkinsfile.hebergement.
// =====================================================
// Auteur : Bigmoletos
// Date : 15-04-2025
// =====================================================
// Ce script attend que les dossiers 'infrastructure/hebergement' soient créés par un script JobDSL parent.

pipelineJob('infrastructure/hebergement/infrastructure_hebergement_config_update') {
    description('''Pipeline pour la gestion de la configuration d'hébergement (dans infrastructure/hebergement)
    Ce pipeline surveille les changements dans le dépôt GitHub d'hébergement
    et applique les mises à jour de configuration nécessaires.''')

    properties {
        githubProjectUrl('https://github.com/bigmoletos/hebergement_serveur')
        pipelineTriggers {
            triggers {
                githubPush()
            }
        }
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/bigmoletos/hebergement_serveur.git')
                        credentials('github-hebergement')
                    }
                    branch('*/main')
                    extensions {
                        cleanBeforeCheckout()
                        cloneOptions {
                            depth(1)
                            shallow(true)
                            timeout(10)
                        }
                    }
                }
            }
            scriptPath('ci-cd/jenkins/Jenkinsfile.hebergement')
            lightweight(true)
        }
    }

    // Autres propriétés du job
    properties {
        disableConcurrentBuilds()
    }

    // Configuration des logs
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
    }
}