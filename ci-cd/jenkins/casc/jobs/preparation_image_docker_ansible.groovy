// hebergement_serveur/ci-cd/jenkins/casc/jobs/preparation_image_docker_ansible.groovy

// Définit un nouveau Pipeline Job nommé 'preparation_image_docker_ansible'
pipelineJob('preparation_image_docker_ansible') {
    description("Pipeline pour construire et pousser l\'image Docker personnalisée ansible-docker (via CasC JobDSL)")

    // Configure la source du pipeline depuis le SCM (Git)
    definition {
        cpsScm {
            scm {
                git {
                    // URL du dépôt contenant le Jenkinsfile.image-builder
                    remote {
                        url('https://gitlab.com/iaproject-fr/airquality.git')
                        // ID du credential Jenkins pour accéder à GitLab
                        credentials('credentialGitlab')
                    }
                    // Branche à utiliser
                    branch('*/main') // Le checkout initial se fait toujours sur main (ou la branche par défaut)
                    // Optionnel: extensions pour affiner le comportement Git
                    // extensions { cleanBeforeCheckout() }
                }
            }
            // Chemin vers le Jenkinsfile DANS le dépôt cloné
            scriptPath('ansible/Jenkinsfile.image-builder')
            // Utilise le checkout léger pour plus d'efficacité
            lightweight(true)
        }
    }

    // Configure les déclencheurs (triggers)
    triggers {
        // Déclencheur GitLab sur Push
        gitlab {
            // Nom de la connexion GitLab configurée dans Jenkins (voir /var/jenkins_home/init.groovy.d/gitlab-config.groovy)
            connection('GitLab')
            triggerOnPush(true)
            triggerOnMergeRequest(false) // Désactivé pour ce job
            triggerOpenMergeRequestOnPush("never")
            // Filtre pour ne déclencher que sur les branches main ou dev
            branchFilter {
                type('RegexBasedFilter')
                sourceBranchRegex('^(main|dev)$') // Regex pour les branches main ou dev
            }
            // Filtre pour ne déclencher que si les changements concernent le dossier ansible/
            pathFilter {
                type('PathBasedFilter')
                includedPaths('ansible/.*') // Regex pour le chemin
            }
            // Nécessite la configuration d'un Secret Token dans le webhook GitLab
            // et dans la configuration globale du plugin GitLab dans Jenkins.
            secretToken(System.getenv('GITLAB_WEBHOOK_SECRET')) // Récupère le token depuis une variable d'env Jenkins
        }
    }

    // Autres propriétés du job (optionnel)
    properties {
        // Empêche les builds concurrents pour ce job si nécessaire
        // disableConcurrentBuilds()
    }
}