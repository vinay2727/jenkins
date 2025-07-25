pipeline {
    agent any

    environment {
        KUBECONFIG = '/c/Users/rbih4/.kube/config'
    }

    parameters {
        string(name: 'REPO_NAME', defaultValue: 'pan-service', description: 'GitHub repo name')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'qa', 'prod'], description: 'Target environment/namespace')
    }

    stages {
        stage('Set Vars') {
            steps {
                script {
                    env.TAG = "${params.REPO_NAME}-${env.BUILD_NUMBER}"
                    env.DOCKERHUB_IMAGE = "drdocker108/${params.REPO_NAME}"
                }
            }
        }

        stage('Checkout App Source') {
            steps {
                git url: "https://github.com/vinay2727/${params.REPO_NAME}.git", branch: 'main'
            }
        }

        stage('Checkout Jenkins Config') {
            steps {
                dir('central-config') {
                    git url: 'https://github.com/vinay2727/jenkins.git', branch: 'main'
                }
            }
        }

        stage('Maven Build') {
            when {
                expression { params.ENVIRONMENT == 'qa' }
            }
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Docker Build') {
            when {
                expression { params.ENVIRONMENT == 'qa' }
            }
            steps {
                sh "docker build -f central-config/Dockerfile -t ${DOCKERHUB_IMAGE}:${TAG} ."
            }
        }

        stage('Push to DockerHub') {
            when {
                expression { params.ENVIRONMENT == 'qa' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKERHUB_IMAGE}:${TAG}
                        docker logout
                    '''
                }
            }
        }

        stage('Promote Image from QA to Prod') {
            when {
                expression { params.ENVIRONMENT == 'prod' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    script {
                        def qaTag = "${params.REPO_NAME}-${env.BUILD_NUMBER}" // Or dynamically determine if needed
                        sh """
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                            docker pull ${DOCKERHUB_IMAGE}:${qaTag}
                            docker tag ${DOCKERHUB_IMAGE}:${qaTag} ${DOCKERHUB_IMAGE}:${TAG}
                            docker push ${DOCKERHUB_IMAGE}:${TAG}
                            docker logout
                        """
                    }
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                script {
                    sh '''
                        echo "🔧 Setting KUBECONFIG..."
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true

                        echo "🔍 Creating namespace if not present: ${ENVIRONMENT}..."
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

                        echo "🚀 Deploying to namespace: ${ENVIRONMENT}..."
                        sed "s|<IMAGE_TAG>|${TAG}|g; s|<REPO_NAME>|${REPO_NAME}|g; s|<ENV>|${ENVIRONMENT}|g" central-config/k8s-deployment.yaml | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${ENVIRONMENT} -f -
                    '''
                }
            }
        }
    }
}
