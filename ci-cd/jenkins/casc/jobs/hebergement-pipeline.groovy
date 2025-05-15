// =====================================================
// Pipeline JobDSL : gestion de la configuration d'hébergement
// - Surveille le dépôt GitHub d'hébergement
// - Applique les mises à jour de configuration nécessaires
// =====================================================
// Auteur : [Votre nom]
// Date : [Date de modification]
// =====================================================
// Création des dossiers parents nécessaires
folder('infrastructure')
folder('infrastructure/hebergement')

pipelineJob('infrastructure/hebergement/config-update') {
    description('''Pipeline pour la gestion de la configuration d'hébergement
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