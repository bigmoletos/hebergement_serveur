pipeline {
    agent {
        docker {
            image 'python:3.9'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        // DOCKER_REGISTRY et DOCKER_IMAGE sont maintenant récupérés depuis l'environnement Jenkins
        // Assurez-vous que DOCKER_USERNAME et AIRQUALITY_IMAGE_NAME sont définis dans le .env
        // DOCKER_REGISTRY = 'your-registry' // Supprimé
        // DOCKER_IMAGE = 'airquality'     // Supprimé
        DOCKER_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh 'pip install -r requirements.txt'
                sh 'python -m pytest tests/'
            }
        }

        stage('Build') {
            steps {
                // Modifié pour utiliser les variables d'env DOCKER_USERNAME et AIRQUALITY_IMAGE_NAME
                sh "docker build -t ${env.DOCKER_USERNAME}/${env.AIRQUALITY_IMAGE_NAME}:${env.BUILD_NUMBER} ."
            }
        }

        stage('Deploy') {
            steps {
                // Attention: Ce docker-compose utilisera potentiellement aussi DOCKER_USERNAME/AIRQUALITY_IMAGE_NAME
                // Assurez-vous que le docker-compose.yml est cohérent ou passe les variables nécessaires.
                sh 'docker-compose -f ../docker/compose/docker-compose.yml up -d airquality'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully'
        }
        failure {
            echo 'Pipeline failed'
        }
    }
}