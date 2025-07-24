pipeline {
    agent any

    parameters {
        string(name: 'REPO_NAME', defaultValue: 'pan-service', description: 'GitHub repo name')
        choice(name: 'ENVIRONMENT', choices: ['qa', 'dev', 'prod'], description: 'Target environment/namespace')
    }

    environment {
        TAG = "${env.BUILD_NUMBER}"
        DOCKERHUB_IMAGE = "drdocker108/${params.REPO_NAME}"
        K8S_YAML = 'k8s-deployment.yaml'
        KUBECONFIG = '/c/Users/rbih4/.kube/config'
    }

    stages {
        stage('Checkout') {
            steps {
                git url: "https://github.com/vinay2727/${params.REPO_NAME}.git", branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKERHUB_IMAGE}:${TAG} ."
                }
            }
        }

        stage('Push to DockerHub') {
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

        stage('Deploy to Minikube') {
            steps {
                script {
                    sh '''
                        echo "🔧 Setting KUBECONFIG..."
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true

                        echo "🔍 Creating namespace if not present: ${ENVIRONMENT}..."
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

                        echo "🚀 Deploying to namespace: ${ENVIRONMENT}"
                        sed "s|<IMAGE_TAG>|${TAG}|g; s|<REPO_NAME>|${REPO_NAME}|g; s|<ENV>|${ENVIRONMENT}|g" ${K8S_YAML} | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${ENVIRONMENT} -f -
                    '''
                }
            }
        }
    }
}
