def call() {
    pipeline {
        agent any

        environment {
            KUBECONFIG = '/c/Users/rbih4/.kube/config'
        }

        parameters {
            string(name: 'REPO_NAME', defaultValue: 'pan-service', description: 'GitHub repo name')
            string(name: 'BRANCH_NAME', defaultValue: 'release/1.0', description: 'Git branch name')
            choice(name: 'ENVIRONMENT', choices: ['dev', 'qa', 'prod'], description: 'Target environment/namespace')
        }

        stages {
            stage('Checkout App Source') {
                steps {
                    git url: "https://github.com/vinay2727/${params.REPO_NAME}.git", branch: "${params.BRANCH_NAME}"
                }
            }

            stage('Build (Only on QA)') {
                when {
                    expression { params.ENVIRONMENT == 'qa' }
                }
                steps {
                    sh 'mvn clean package -DskipTests'
                }
            }

            stage('Docker Build & Push (Only on QA)') {
                when {
                    expression { params.ENVIRONMENT == 'qa' }
                }
                steps {
                    script {
                        env.TAG = "${params.REPO_NAME}-${env.BUILD_NUMBER}"
                        env.IMAGE_NAME = "drdocker108/${params.REPO_NAME}:${env.TAG}"

                        sh """
                            docker build -t ${IMAGE_NAME} .
                            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                            docker push ${IMAGE_NAME}
                            docker logout
                        """
                    }
                }
            }

            stage('Promote from QA to Prod') {
                when {
                    expression { params.ENVIRONMENT == 'prod' }
                }
                steps {
                    script {
                        env.QA_TAG = "${params.REPO_NAME}-${env.BUILD_NUMBER}"
                        env.NEW_TAG = "${params.REPO_NAME}-${env.BUILD_NUMBER}-prod"

                        sh """
                            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                            docker pull drdocker108/${params.REPO_NAME}:${QA_TAG} || exit 1
                            docker tag drdocker108/${params.REPO_NAME}:${QA_TAG} drdocker108/${params.REPO_NAME}:${NEW_TAG}
                            docker push drdocker108/${params.REPO_NAME}:${NEW_TAG}
                            docker logout
                        """
                    }
                }
            }

            stage('Deploy to Minikube') {
                steps {
                    script {
                        def tagToUse = (params.ENVIRONMENT == 'prod') ? "${params.REPO_NAME}-${env.BUILD_NUMBER}-prod" : "${params.REPO_NAME}-${env.BUILD_NUMBER}"

                        sh """
                            kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true
                            kubectl --kubeconfig=${KUBECONFIG} create namespace ${params.ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

                            sed "s|<IMAGE_TAG>|${tagToUse}|g; s|<REPO_NAME>|${params.REPO_NAME}|g; s|<ENV>|${params.ENVIRONMENT}|g" central-config/k8s-deployment.yaml | \
                            kubectl --kubeconfig=${KUBECONFIG} apply -n ${params.ENVIRONMENT} -f -
                        """
                    }
                }
            }
        }
    }
}

return this
