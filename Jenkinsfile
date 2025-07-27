def call() {
    pipeline {
        agent any

        environment {
            KUBECONFIG = '/c/Users/rbih4/.kube/config'
            CONFIG_REPO = 'https://github.com/vinay2727/jenkins.git'
            CONFIG_BRANCH = 'main'
            DOCKERHUB_IMAGE = "drdocker108/${env.REPO_NAME}"
        }

        parameters {
            choice(name: 'ENVIRONMENT', choices: ['qa', 'prod'], description: 'Select the environment')
        }

        stages {
            stage('Init') {
                steps {
                    script {
                        def parts = env.JOB_NAME.split('/')
                        env.REPO_NAME = parts[1]
                        env.BRANCH_NAME = java.net.URLDecoder.decode(parts[2], "UTF-8")
                        env.TAG = "${env.REPO_NAME}-${env.BUILD_NUMBER}"
                        env.DOCKER_IMAGE = "drdocker108/${env.REPO_NAME}:${env.TAG}"

                        echo "Repo: ${env.REPO_NAME}, Branch: ${env.BRANCH_NAME}, Tag: ${env.TAG}, Env: ${params.ENVIRONMENT}"
                    }
                }
            }
            
            stage('Checkout Central Pipeline') {
                steps { 
                    dir('central-config') {
                        git url: 'https://github.com/vinay2727/jenkins.git', branch: 'main', credentialsId: 'Github-PAT'
                    }
                }
            }
                     
            stage('Checkout Source') {
                steps {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "${env.BRANCH_NAME}"]],
                        userRemoteConfigs: [[
                            url: "https://github.com/vinay2727/${env.REPO_NAME}.git",
                            credentialsId: 'Github-PAT'
                        ]]
                    ])
                }
            }

            stage('Maven Build') {
                when { expression { params.ENVIRONMENT == 'qa' } }
                steps {
                    sh 'mvn clean package -DskipTests'
                }
            }

            stage('Docker Build & Push') {
                when { expression { params.ENVIRONMENT == 'qa' } }
                steps {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                            docker build -f central-config/Dockerfile -t ${DOCKER_IMAGE} .
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                            docker push ${DOCKER_IMAGE}
                            docker logout
                        """
                    }
                }
            }

            stage('Deploy to QA') {
                when { expression { params.ENVIRONMENT == 'qa' } }
                steps {
                    sh """
                        echo "🔧 Setting KUBECONFIG..."
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true

                        echo "🔍 Creating namespace if not present: ${params.ENVIRONMENT}..."
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${params.ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

                        echo "🚀 Deploying QA image: ${DOCKER_IMAGE} to ${params.ENVIRONMENT} namespace..."
                        sed "s|<IMAGE_TAG>|${TAG}|g; s|<REPO_NAME>|${env.REPO_NAME}|g; s|<ENV>|${params.ENVIRONMENT}|g" central-config/k8s-deployment.yaml | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${params.ENVIRONMENT} -f -
                    """
                }
            }

            stage('Promote QA to Prod') {
                when { expression { params.ENVIRONMENT == 'prod' } }
                steps {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        script {
                            def qaImage = sh(
                                script: "kubectl --kubeconfig=${KUBECONFIG} get pods -n qa -l app=${env.REPO_NAME} -o jsonpath='{.items[0].spec.containers[0].image}'",
                                returnStdout: true
                            ).trim()

                            def prodTag = "${env.REPO_NAME}-${env.BUILD_NUMBER}"

                            sh """
                                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                                docker pull ${qaImage}
                                docker tag ${qaImage} ${DOCKERHUB_IMAGE}:${prodTag}
                                docker push ${DOCKERHUB_IMAGE}:${prodTag}
                                docker logout
                            """
                        }
                    }
                }
            }

            stage('Deploy to Prod') {
                when { expression { params.ENVIRONMENT == 'prod' } }
                steps {
                    sh """
                        echo "🔧 Setting KUBECONFIG..."
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true

                        echo "🚀 Deploying PROD image: ${DOCKERHUB_IMAGE}:${REPO_NAME}-${BUILD_NUMBER} to prod namespace..."
                        sed "s|<IMAGE_TAG>|${REPO_NAME}-${BUILD_NUMBER}|g; s|<REPO_NAME>|${env.REPO_NAME}|g; s|<ENV>|${params.ENVIRONMENT}|g" central-config/k8s-deployment.yaml | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${params.ENVIRONMENT} -f -
                    """
                }
            }
        }
    }
}
return this
