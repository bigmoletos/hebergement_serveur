// =====================================================
// Pipeline JobDSL : CI/CD pour l'application AirQuality
// - Déclencheur GitLab, gestion des logs, configuration globale
// =====================================================
// Auteur : [Votre nom]
// Date : [Date de modification]
// =====================================================

folder('applications')
folder('applications/airquality')

pipelineJob('applications/airquality/build-and-deploy') {
    description("Pipeline CI/CD pour l'application de qualité de l'air")

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
            // Utiliser le Jenkinsfile du projet qualité air
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
