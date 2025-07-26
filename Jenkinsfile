def call() {
    pipeline {
        agent any

        environment {
            KUBECONFIG = '/c/Users/rbih4/.kube/config'
        }

        parameters {
            choice(name: 'ENVIRONMENT', choices: ['qa', 'prod'], description: 'Select the deployment environment')
        }

        stages {
            stage('Extract Context') {
                steps {
                    script {
                        def jobParts = env.JOB_NAME.split('/')
                        env.REPO_NAME = jobParts[1]
                        env.BRANCH_NAME = jobParts[2]
                        env.TAG = "${env.REPO_NAME}-${env.BUILD_NUMBER}"
                        env.DOCKER_IMAGE = "drdocker108/${env.REPO_NAME}:${env.TAG}"
                        echo "Repo: ${env.REPO_NAME}, Branch: ${env.BRANCH_NAME}, ENV: ${params.ENVIRONMENT}"
                    }
                }
            }

            stage('Checkout Source Repo') {
                steps {
                    git url: "https://github.com/vinay2727/${env.REPO_NAME}.git", branch: "${env.BRANCH_NAME}"
                }
            }

            stage('Checkout Central Config') {
                steps {
                    dir('central-config') {
                        git url: 'https://github.com/vinay2727/jenkins.git', branch: 'main'
                    }
                }
            }

            stage('Build & Push (only in QA)') {
                when {
                    expression { params.ENVIRONMENT == 'qa' }
                }
                steps {
                    sh 'mvn clean package -DskipTests'
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                            docker build -t ${env.DOCKER_IMAGE} .
                            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                            docker push ${env.DOCKER_IMAGE}
                            docker logout
                        """
                    }
                }
            }

            stage('Fetch QA Image Tag (only in Prod)') {
                when {
                    expression { params.ENVIRONMENT == 'prod' }
                }
                steps {
                    script {
                        def imageTag = sh(
                            script: """
                                kubectl --kubeconfig=${KUBECONFIG} -n qa get pods -l app=${env.REPO_NAME} -o jsonpath='{.items[0].spec.containers[0].image}'
                            """,
                            returnStdout: true
                        ).trim()
                        env.DOCKER_IMAGE = imageTag
                        echo "Promoting image from QA: ${env.DOCKER_IMAGE}"
                    }
                }
            }

            stage('Deploy to Kubernetes') {
                steps {
                    sh """
                        echo "Using context: minikube"
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true

                        echo "Creating namespace ${params.ENVIRONMENT} if missing..."
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${params.ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

                        echo "Deploying image: ${env.DOCKER_IMAGE} to ${params.ENVIRONMENT}"
                        sed "s|<IMAGE_TAG>|${env.DOCKER_IMAGE}|g; s|<REPO_NAME>|${env.REPO_NAME}|g; s|<ENV>|${params.ENVIRONMENT}|g" central-config/k8s-deployment.yaml | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${params.ENVIRONMENT} -f -
                    """
                }
            }
        }
    }
}

return this
