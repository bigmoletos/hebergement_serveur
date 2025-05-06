// Création des dossiers parents nécessaires
folder('applications')
folder('applications/airquality')

pipelineJob('applications/airquality/build-and-deploy') {
    description('Pipeline CI/CD pour l\'application de qualité de l\'air')

    properties {
        githubProjectUrl('https://gitlab.com/iaproject-fr/airquality')
        /* // Temporairement commenté pour isoler le problème de checkout SCM initial
        pipelineTriggers {
            triggers {
                gitlab {
                    triggerOnPush(true)
                    triggerOnMergeRequest(true)
                    branchFilterType('All')
                }
            }
        }
        */
    }

    definition {
        cps {
            script('''
                pipeline {
                    agent none

                    // Définition des variables d'environnement globales
                    environment {
                        // Images Docker
                        NAME_IMAGE_API = "air_quality_api"
                        NAME_IMAGE_IHM = "air_quality_ihm"
                        NAME_IMAGE_IHM_TEST = "air_quality_ihm_test"

                        // Chemins des répertoires de test
                        PATH_TEST_API = "/home/ubuntu/testapi"
                        PATH_TEST_IHM = "/home/ubuntu/testihm"
                        PATH_TEST_IHM_SERVICE = "${PATH_TEST_IHM}/services/api_ihm"

                        // Chemins des fichiers de configuration
                        PATH_PLAYBOOK = "ansible/playbooks/deploy.yml"
                        PATH_DOCKERFILE = "services/api_modelisation/Dockerfile"
                        PATH_INVENTORY = "ansible/inventories/ansible.inv"
                        PATH_DOCKER_COMPOSE = "docker/docker-compose.test.yml"

                        // Credentials et authentification
                        CREDENTIAL_GITLAB = "credentialGitlab"
                        CREDENTIAL_DOCKERHUB = "dockerhub_airquality"
                        LOGIN_DOCKERHUB = "bigmoletos"

                        // Fichiers de requirements Python
                        REQUIREMENTS_DEPLOIEMENT = "services/requirements.txt"
                        REQUIREMENTS_MODELISATION = "services/api_modelisation/requirements.txt"
                        REQUIREMENTS_IHM = "services/api_ihm/requirements.txt"
                        REQUIREMENTS_IHM_TEST = "services/api_ihm/requirements-test.txt"

                        // Configuration de l'environnement
                        VENV_PATH = "venv"
                        ANSIBLE_HOST_KEY_CHECKING = "False"
                        API_PORT = '8092' // Port interne sur lequel l'application API écoute, utilisé par Ansible
                        API_HOST = '0.0.0.0' // L'application API écoute sur toutes les interfaces dans son conteneur
                        PYTHON_ENV = 'test'
                        FLASK_DEBUG = '1'
                        IHM_PORT = '8093' // Port interne sur lequel l'application IHM écoute, utilisé par Ansible

                        // Configuration Traefik
                        DOMAIN = 'airquality.iaproject.fr'
                        TRAEFIK_NETWORK = 'traefik-public' // Nom du réseau Docker utilisé par Traefik et les services
                        API_SUBDOMAIN = 'api'
                        IHM_SUBDOMAIN = "${env.OVH_DNS_SUBDOMAIN}" // Correction: Utilisation de guillemets pour l'interpolation
                        OVH_DNS_ZONE = "${env.OVH_DNS_ZONE}"     // Correction: Utilisation de guillemets pour l'interpolation

                        // URL du dépôt GitLab
                        URL_GITLAB = "https://gitlab.com/iaproject-fr/airquality.git"

                        // BUILD_TAG déplacé car sh() ne fonctionne pas directement dans environment{}
                        // BUILD_TAG = sh(script: 'date +%Y%m%d_%H%M%S', returnStdout: true).trim()
                    }

                    stages {
                        // Étape 1: Clonage du dépôt
                        stage('Clone Repository') {
                            agent any
                            steps {
                                // Définir BUILD_TAG ici
                                script {
                                    env.BUILD_TAG = sh(script: 'date +%Y%m%d_%H%M%S', returnStdout: true).trim()
                                }
                                // Récupération du code depuis GitLab avec authentification
                                git(
                                    url: env.URL_GITLAB, // Utiliser env.URL_GITLAB
                                    branch: "main",
                                    credentialsId: env.CREDENTIAL_GITLAB // Utiliser env.CREDENTIAL_GITLAB
                                )
                            }
                        }

                        // Étape 2: Exécution des tests
                        stage('Run Tests') {
                            agent {
                                docker {
                                    image 'docker:latest'
                                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                                    reuseNode true
                                }
                            }
                            steps {
                                script {
                                    echo "Running tests"
                                    def localIhmservicePath = env.PATH_TEST_IHM_SERVICE // Renommée et utilisée pour construire la commande ci-dessous
                                    def commandForCsvCheck = "ls -la ${localIhmservicePath}/data/datasets/environment_data_analysis.csv || true"
                                    dir('services/api_ihm') {
                                        // ... contenu du script sh ...
                                        sh """
                                            echo "Checking test structure..."
                                            mkdir -p tests/reports
                                            ls -la
                                            ls -la tests/ || {
                                                echo "Creating tests directory structure"
                                                mkdir -p tests
                                            }
                                        """
                                        sh """
                                            echo "Building test image..."
                                            docker build \
                                                --build-arg PYTHON_ENV=${env.PYTHON_ENV} \
                                                --build-arg FLASK_DEBUG=${env.FLASK_DEBUG} \
                                                -t ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM_TEST}:latest \
                                                -f Dockerfile.test . || {
                                                    echo "Failed to build test image"
                                                    exit 1
                                                }
                                        """
                                        sh """
                                            echo "Starting test container..."
                                            docker rm -f api_ihm_test || true
                                            echo "Checking CSV file..."
                                            ${commandForCsvCheck}
                                            docker run --name api_ihm_test \\
                                                 -p 8093:8093 \\
                                                 -v \\$(pwd)/tests/reports:/app/tests/reports \\
                                                 -v \\$(pwd)/data/datasets:/app/data/datasets:ro \\
                                                 ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM_TEST}:latest || {
                                                    echo "Test container failed"
                                                    echo "Container logs:"
                                                    docker logs api_ihm_test
                                                    docker rm -f api_ihm_test || true
                                                    exit 1
                                                }
                                        """
                                        sh """
                                            echo "Test container logs:"
                                            docker logs api_ihm_test || true
                                        """
                                        junit allowEmptyResults: true, testResults: '**/tests/reports/*.xml'
                                    }
                                }
                            }
                        }

                        // Étape 3: Construction des images Docker
                        stage('Build Docker Images') {
                            agent {
                                docker {
                                    image 'docker:latest'
                                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                                    reuseNode true
                                }
                            }
                            steps {
                                script {
                                    echo "Building Docker images"
                                    dir('services/api_modelisation') {
                                        sh """
                                            echo "Building API image..."
                                            docker build -t ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_API}:latest . || {
                                                echo "Failed to build API image"
                                                exit 1
                                            }
                                        """
                                    }
                                    dir('services/api_ihm') {
                                        sh """
                                            echo "Building IHM image..."
                                            docker build -t ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:${env.BUILD_TAG} -t ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:latest .
                                            # Push commenté car il y a une étape Push dédiée
                                            # docker push ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:${env.BUILD_TAG}
                                            # docker push ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:latest
                                        """
                                    }
                                }
                            }
                        }

                        // Nouvelle étape : Vérification des images Docker
                        stage('Verify Docker Images') {
                            agent {
                                docker {
                                    image 'docker:latest'
                                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                                    reuseNode true
                                }
                            }
                            steps {
                                script {
                                    echo "Verifying Docker images..."
                                    sh """
                                        echo "Checking built images..."
                                        docker images | grep ${env.NAME_IMAGE_API} || { echo "API image not found"; exit 1; }
                                        docker images | grep ${env.NAME_IMAGE_IHM} || { echo "IHM image not found"; exit 1; }
                                        docker images | grep ${env.NAME_IMAGE_IHM_TEST} || { echo "IHM test image not found"; exit 1; }
                                        echo "Checking image sizes..."
                                        docker images --format "{{.Repository}}:{{.Tag}} - Size: {{.Size}}" | grep ${env.NAME_IMAGE_API}
                                        docker images --format "{{.Repository}}:{{.Tag}} - Size: {{.Size}}" | grep ${env.NAME_IMAGE_IHM}
                                        docker images --format "{{.Repository}}:{{.Tag}} - Size: {{.Size}}" | grep ${env.NAME_IMAGE_IHM_TEST}
                                        echo "Testing image pulls..."
                                        docker pull ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_API}:latest || echo "API image not yet on DockerHub"
                                        docker pull ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:latest || echo "IHM image not yet on DockerHub"
                                        echo "Verifying templates in IHM image..."
                                        docker run --rm ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:latest ls -la /app/src/templates/
                                        echo "Testing Flask application..."
                                    """

                                    // Utiliser withCredentials ici pour les secrets BDD
                                    withCredentials([
                                        usernamePassword(credentialsId: 'bdd_user1', usernameVariable: 'BDD_USER1_USERNAME', passwordVariable: 'BDD_USER1_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user2', usernameVariable: 'BDD_USER2_USERNAME', passwordVariable: 'BDD_USER2_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user3', usernameVariable: 'BDD_USER3_USERNAME', passwordVariable: 'BDD_USER3_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user4', usernameVariable: 'BDD_USER4_USERNAME', passwordVariable: 'BDD_USER4_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user_admin', usernameVariable: 'BDD_USER_ADMIN_USERNAME', passwordVariable: 'BDD_USER_ADMIN_PASSWORD')
                                    ]) {
                                        sh """
                                            docker run --rm -d --name test_ihm -p 8093:8093 \\
                                                -e PYTHON_ENV=test \\
                                                -e FLASK_DEBUG=1 \\
                                                -e DB_USER1=\"${BDD_USER1_USERNAME}" \\
                                                -e DB_USER2=\"${BDD_USER2_USERNAME}" \\
                                                -e DB_USER3=\"${BDD_USER3_USERNAME}" \\
                                                -e DB_USER4=\"${BDD_USER4_USERNAME}" \\
                                                -e DB_PASSWORD1=\"${BDD_USER1_PASSWORD}" \\
                                                -e DB_PASSWORD2=\"${BDD_USER2_PASSWORD}" \\
                                                -e DB_PASSWORD3=\"${BDD_USER3_PASSWORD}" \\
                                                -e DB_PASSWORD4=\"${BDD_USER4_PASSWORD}" \\
                                                -e ADMIN_PASSWORD=\"${BDD_USER_ADMIN_PASSWORD}" \\
                                                ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:latest
                                        """
                                    }
                                    sh "sleep 10"
                                    sh "curl -v http://localhost:8093/health || true"
                                    sh "docker logs test_ihm || true"
                                    sh "docker rm -f test_ihm || true"
                                }
                            }
                        }

                        // Étape 4: Push des images vers DockerHub
                        stage('Push Docker Images') {
                            agent {
                                docker {
                                    image 'docker:latest'
                                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                                    reuseNode true
                                }
                            }
                            steps {
                                script {
                                    sh """
                                        echo "Cleaning up old containers..."
                                        docker rm -f api_ihm_test || true
                                        docker rm -f api_ihm || true
                                    """
                                    withCredentials([usernamePassword(credentialsId: env.CREDENTIAL_DOCKERHUB, // Utiliser env.
                                                                    usernameVariable: 'DOCKER_USER',
                                                                    passwordVariable: 'DOCKER_PASSWORD')]) {
                                        sh """
                                            echo "Attempting login for user: \\${DOCKER_USER}" # Diagnostic echo
                                            echo "\\${DOCKER_PASSWORD}" | docker login -u "\\${DOCKER_USER}" --password-stdin
                                            docker push ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_API}:latest
                                            # Push de latest ici aussi
                                            docker push ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:latest
                                            docker push ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM}:${env.BUILD_TAG}
                                            docker push ${env.LOGIN_DOCKERHUB}/${env.NAME_IMAGE_IHM_TEST}:latest
                                        """
                                    }
                                }
                            }
                        }

                        // Étape 5: Déploiement avec Ansible
                        stage('Run Ansible Playbook') {
                            agent {
                                // !! DOIT UTILISER L'IMAGE CONSTRUITE PRÉCÉDEMMENT !!
                                docker {
                                    image 'bigmoletos/ansible-docker:latest' // Utiliser l'image perso
                                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                                    reuseNode true
                                }
                            }
                            steps {
                                script {
                                    echo "Running Ansible playbook ${env.PATH_PLAYBOOK}"
                                    withCredentials([
                                        usernamePassword(credentialsId: env.CREDENTIAL_DOCKERHUB, // Utiliser env.
                                                       usernameVariable: 'DOCKER_USER',
                                                       passwordVariable: 'DOCKER_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user1', usernameVariable: 'BDD_USER1_USERNAME', passwordVariable: 'BDD_USER1_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user2', usernameVariable: 'BDD_USER2_USERNAME', passwordVariable: 'BDD_USER2_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user3', usernameVariable: 'BDD_USER3_USERNAME', passwordVariable: 'BDD_USER3_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user4', usernameVariable: 'BDD_USER4_USERNAME', passwordVariable: 'BDD_USER4_PASSWORD'),
                                        usernamePassword(credentialsId: 'bdd_user_admin', usernameVariable: 'BDD_USER_ADMIN_USERNAME', passwordVariable: 'BDD_USER_ADMIN_PASSWORD')
                                    ]) {
                                        sh """
                                            echo "Checking container status before deployment..."
                                            docker ps -a
                                            # ... (autres vérifications sh) ...
                                            echo "Templates directory content:"
                                            # Le WORKSPACE est défini par Jenkins, contient le code cloné
                                            ls -la ${WORKSPACE}/services/api_ihm/src/templates/
                                        """
                                        sh """#!/bin/bash
                                            ansible-playbook ${env.PATH_PLAYBOOK} \
                                                -i ${env.PATH_INVENTORY} \
                                                -e "docker_user=${DOCKER_USER}" \
                                                -e "docker_password=${DOCKER_PASSWORD}" \
                                                -e "api_port=${env.API_PORT}" \
                                                -e "ihm_port=${env.IHM_PORT}" \
                                                -e "api_host=${env.API_HOST}" \
                                                -e "debug_mode=true" \
                                                -e "name_image_ihm_test=${env.NAME_IMAGE_IHM_TEST}" \
                                                -e "bdd_user1=${BDD_USER1_USERNAME}" \
                                                -e "bdd_user2=${BDD_USER2_USERNAME}" \
                                                -e "bdd_user3=${BDD_USER3_USERNAME}" \
                                                -e "bdd_user4=${BDD_USER4_USERNAME}" \
                                                -e "bdd_user1_password=${BDD_USER1_PASSWORD}" \
                                                -e "bdd_user2_password=${BDD_USER2_PASSWORD}" \
                                                -e "bdd_user3_password=${BDD_USER3_PASSWORD}" \
                                                -e "bdd_user4_password=${BDD_USER4_PASSWORD}" \
                                                -e "bdd_user_admin_password=${BDD_USER_ADMIN_PASSWORD}" \
                                                -e "domain=${env.DOMAIN}" \
                                                -e "traefik_network=${env.TRAEFIK_NETWORK}" \
                                                -e "api_subdomain=${env.API_SUBDOMAIN}" \
                                                -e "ihm_subdomain=${env.IHM_SUBDOMAIN}" \
                                                -vv
                                        """
                                        sh """
                                            echo "=== Post-deployment checks ==="
                                            # ... (vérifications post-deployment) ...
                                        """
                                    }
                                }
                            }
                        }
                    }

                    post {
                        always {
                            steps {
                                echo 'Nettoyage du workspace Jenkins.'
                                cleanWs()
                            }
                        }
                    }
                }
            ''') // Fin de la chaîne de script
            // Indique que le script provient directement de la définition et non du SCM
            sandbox(false) // Ou true si vous avez besoin du sandboxing Groovy
        }
    }
}
