// =====================================================
// Pipeline JobDSL : CI/CD pour l'application AirQuality
// - Déploie l'application à partir du dépôt GitLab
// - Déclencheur GitLab, gestion des logs, configuration globale
// =====================================================
// Auteur : [Votre nom]
// Date : [Date de modification]
// =====================================================
// Ce job CI/CD déploie l'application de qualité de l'air à partir du dépôt GitLab projet_qualite_air
folder('applications')
folder('applications/airquality')

pipelineJob('applications/airquality/build-and-deploy') {
    description("Pipeline CI/CD pour l'application de qualité de l'air (projet_qualite_air sur GitLab)")

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://gitlab.com/iaproject-fr/airquality.git')
                        credentials('credentialGitlab')
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
            // Chemin du Jenkinsfile dans le dépôt projet_qualite_air (GitLab)
            scriptPath('ci-cd/Jenkinsfile')
            lightweight(true)
        }
    }

    triggers {
        gitlab {
            triggerOnPush(true)
            triggerOnMergeRequest(false)
            triggerOpenMergeRequestOnPush("never")
            secretToken(System.getenv('GITLAB_WEBHOOK_SECRET'))
        }
    }

    properties {
        disableConcurrentBuilds()
    }

    // Configuration des logs
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
    }

    // Configuration Git globale
    configure { node ->
        node / 'properties' / 'hudson.plugins.disk__usage.DiskUsageProperty' {
            'diskUsageNode' {
                'size'('0')
            }
        }
        node / 'properties' / 'org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty' {
            'triggers' {
                'hudson.triggers.SCMTrigger' {
                    'spec'('H/15 * * * *')
                }
            }
        }
    }
}
