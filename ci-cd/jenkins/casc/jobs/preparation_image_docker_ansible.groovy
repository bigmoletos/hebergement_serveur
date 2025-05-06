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
                    branch('*/main') // Assurez-vous que c'est la bonne branche
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
        // Déclenche périodiquement en interrogeant le SCM pour les changements
        pollSCM {
            // Toutes les 15 minutes environ. Ajustez si nécessaire.
            scmpoll_spec('H/15 * * * *')
            // Important: Ceci déclenchera sur TOUT changement dans la branche.
            // Pour limiter aux changements dans 'ansible/', il faut affiner,
            // soit via l'extension Git SCM 'polling' dans la définition ci-dessus,
            // soit via l'UI après la création initiale. Commençons simplement.
        }
    }

    // Autres propriétés du job (optionnel)
    properties {
        // Empêche les builds concurrents pour ce job si nécessaire
        // disableConcurrentBuilds()
    }
}