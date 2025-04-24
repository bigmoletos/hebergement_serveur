pipelineJob('applications/airquality/build-and-deploy') {
    description('Pipeline CI/CD pour l\'application de qualité de l\'air')

    properties {
        githubProjectUrl('https://gitlab.com/iaproject/projet_qualite_air')
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
                        url('https://gitlab.com/iaproject/projet_qualite_air.git')
                        credentials('gitlab-token')
                    }
                    branches('*/main', '*/develop')
                }
            }
            scriptPath('Jenkinsfile')
        }
    }
}