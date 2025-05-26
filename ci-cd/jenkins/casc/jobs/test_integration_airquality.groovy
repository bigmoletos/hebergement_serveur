// =====================================================
// Pipeline JobDSL : Tests d'intégration Airquality
// - Exécute les tests d'intégration pour l'application Airquality
// - Gère le montage des volumes Docker pour les tests
// - Vérifie l'intégration des différents composants
// =====================================================
// Auteur : Bigmoletos
// Date : 15-04-2025
// =====================================================

pipelineJob('infrastructure/hebergement/test_integration_airquality') {
    description('''Pipeline pour l'exécution des tests d'intégration de l'application Airquality.
    Ce pipeline gère :
    - Le montage des volumes Docker
    - L'exécution des tests d'intégration
    - La génération des rapports de tests''')

    properties {
        githubProjectUrl('https://gitlab.com/iaproject-fr/airquality.git')
    }

    parameters {
        stringParam {
            name('BRANCH_NAME')
            defaultValue('main')
            description('Branche à tester')
        }
        stringParam {
            name('TEST_VOLUME_NAME')
            defaultValue('integration_tests_vol_${BUILD_TAG}')
            description('Nom du volume pour les tests')
        }
        booleanParam {
            name('DEBUG_MODE')
            defaultValue(false)
            description('Activer le mode debug pour plus de logs')
        }
        stringParam {
            name('DOCKER_REGISTRY')
            defaultValue('docker.io')
            description('Registry Docker à utiliser')
        }
        stringParam {
            name('DOCKER_NAMESPACE')
            defaultValue('${DOCKER_USERNAME}')
            description('Namespace Docker (votre username)')
        }
        stringParam {
            name('IMAGE_NAME')
            defaultValue('air_quality_ihm')
            description('Nom de l\'image Docker')
        }
        stringParam {
            name('IMAGE_TAG')
            defaultValue('latest')
            description('Tag de l\'image Docker')
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
                    branch('${BRANCH_NAME}')
                    extensions {
                        cleanBeforeCheckout()
                        cloneOptions {
                            timeout(10)
                        }
                    }
                }
            }
            scriptPath('ci-cd/jenkins/Jenkinsfile.integration-tests')
            lightweight(true)
        }
    }

    // Configuration des triggers
    triggers {
        gitlab {
            triggerOnPush(true)
            triggerOnMergeRequest(true)
            triggerOpenMergeRequestOnPush('source')
            secretToken(System.getenv('GITLAB_WEBHOOK_SECRET'))
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

    // Configuration des credentials
    configure { project ->
        // Ajout du trigger GitHub
        def props = project / 'properties'
        def triggersNode = props / 'org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty'
        triggersNode / 'triggers' {
            'com.cloudbees.jenkins.GitHubPushTrigger' {
                spec('')
            }
        }
        // Ajout des credentials Docker Hub
        def wrappersNode = project.get('buildWrappers')
        if (!wrappersNode) {
            wrappersNode = project.appendNode('buildWrappers')
        }
        wrappersNode << 'org.jenkinsci.plugins.credentialsbinding.impl.SecretBuildWrapper' {
            bindings {
                'org.jenkinsci.plugins.credentialsbinding.impl.UsernamePasswordMultiBinding' {
                    credentialsId('dockerhub_airquality')
                    usernameVariable('DOCKER_USERNAME')
                    passwordVariable('DOCKER_PASSWORD')
                }
            }
        }
    }
}