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
            stage('Prepare') {
                steps {
                    script {
                        def parts = env.JOB_NAME.split('/')
                        env.REPO_NAME = parts[1]
                        env.BRANCH_NAME = java.net.URLDecoder.decode(parts[2], "UTF-8")
                        env.TAG = "${env.REPO_NAME}-${env.BUILD_NUMBER}"
                        env.DOCKER_IMAGE = "drdocker108/${env.REPO_NAME}:${env.TAG}"

                        echo "Repo: ${env.REPO_NAME}, Branch: ${env.BRANCH_NAME}, ENV: ${params.ENVIRONMENT}"
                        sh "git ls-remote https://github.com/vinay2727/${env.REPO_NAME}.git"
                    }
                }
            }

            stage('Checkout') {
                steps {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "${env.BRANCH_NAME}"]],
                        userRemoteConfigs: [[
                            url: "https://github.com/vinay2727/${env.REPO_NAME}.git",
                            credentialsId: 'github-creds'
                        ]]
                    ])
                }
            }

            stage('Build & Push') {
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

            stage('Promote from QA') {
                when {
                    expression { params.ENVIRONMENT == 'prod' }
                }
                steps {
                    script {
                        env.DOCKER_IMAGE = sh(
                            script: "kubectl --kubeconfig=${KUBECONFIG} -n qa get pods -l app=${env.REPO_NAME} -o jsonpath='{.items[0].spec.containers[0].image}'",
                            returnStdout: true
                        ).trim()
                        echo "Using QA image: ${env.DOCKER_IMAGE}"
                    }
                }
            }

            stage('Deploy') {
                steps {
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${params.ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -
                        sed "s|<IMAGE_TAG>|${env.DOCKER_IMAGE}|g; s|<REPO_NAME>|${env.REPO_NAME}|g; s|<ENV>|${params.ENVIRONMENT}|g" k8s-deployment.yaml | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${params.ENVIRONMENT} -f -
                    """
                }
            }
        }
    }
}
