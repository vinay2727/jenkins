pipeline {
    agent any

    parameters {
        string(name: 'REPO_NAME', defaultValue: 'demo', description: 'GitHub Repo name only')
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branch name')
    }

    environment {
        DOCKER_REPO = 'drdocker108'
        IMAGE_TAG = "${params.REPO_NAME}-${env.BUILD_ID}"
        KUBECONFIG = "/c/Users/rbih4/.kube/config"
    }

    stages {
        stage('Manager Approval') {
            steps {
                script {
                    def approved = input(
                        message: 'Manager Approval Required',
                        parameters: [choice(name: 'Approve', choices: ['No', 'Yes'], description: 'Do you approve deployment?')]
                    )
                    if (approved != 'Yes') {
                        error("⛔ Deployment not approved.")
                    }
                }
            }
        }

        stage('Checkout Source') {
            steps {
                dir('src') {
                    git url: "https://github.com/vinay2727/${params.REPO_NAME}.git", branch: "${params.BRANCH}"
                }
            }
        }

        stage('Copy Central Files') {
            steps {
                sh """
                    cp Dockerfile src/
                    cp k8s-deployment.yaml src/
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('src') {
                    script {
                        sh """
                            docker build -t ${DOCKER_REPO}/${params.REPO_NAME}:${IMAGE_TAG} .
                        """
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    dir('src') {
                        sh '''
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                            docker push ${DOCKER_REPO}/${REPO_NAME}:${IMAGE_TAG}
                            docker logout
                        '''
                    }
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                dir('src') {
                    sh '''
                        echo "🌐 Deploying to Minikube..."
                        kubectl --kubeconfig=$KUBECONFIG config use-context minikube || true

                        sed "s|<IMAGE_TAG>|${IMAGE_TAG}|g; s|<REPO_NAME>|${REPO_NAME}|g" k8s-deployment.yaml | \
                        kubectl --kubeconfig=$KUBECONFIG apply -f -
                    '''
                }
            }
        }
    }
}
