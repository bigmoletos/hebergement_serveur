// Création des dossiers parents nécessaires
folder('applications')
folder('applications/airquality')

pipelineJob('applications/airquality/build-and-deploy') {
    description('''Pipeline CI/CD pour l'application de qualité de l'air
    Note: Ce pipeline utilise le Jenkinsfile du dépôt GitLab du projet,
    tandis que la configuration Jenkins elle-même est hébergée sur GitHub.''')

    properties {
        githubProjectUrl('https://gitlab.com/iaproject-fr/airquality')
    }

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
            scriptPath('Jenkinsfile')
            lightweight(true)
        }
    }

    // Configure les déclencheurs
    triggers {
        gitlab {
            triggerOnPush(true)
            triggerOnMergeRequest(false)
            triggerOpenMergeRequestOnPush("never")
            secretToken(System.getenv('GITLAB_WEBHOOK_SECRET'))
            branchFilterType("NameBasedFilter")
            includeBranchesSpec("main")
        }
    }

    // Autres propriétés du job
    properties {
        disableConcurrentBuilds()
        rebuilderProperty {
            autoRebuild(false)
        }
        durabilityHint('PERFORMANCE_OPTIMIZED')
    }
}
