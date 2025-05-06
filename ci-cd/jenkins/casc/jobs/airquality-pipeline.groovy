// Création des dossiers parents nécessaires
folder('applications')
folder('applications/airquality')

pipelineJob('applications/airquality/build-and-deploy') {
    description('Pipeline CI/CD pour l\'application de qualité de l\'air')

    properties {
        githubProjectUrl('https://gitlab.com/iaproject-fr/airquality')
        pipelineTriggers {
            triggers {
                gitlab {
                    triggerOnPush(true)
                    triggerOnMergeRequest(true)
                    branchFilterType('All')
                }
            }
        }
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://gitlab.com/iaproject-fr/airquality.git')
                        credentials('credentialGitlab')
                    }
                    branches('*/main', '*/dev')
                }
            }
            scriptPath('ci-cd/Jenkinsfile')
            lightweight(false)
        }
    }
}