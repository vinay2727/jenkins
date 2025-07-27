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
            stage('Context Resolution') {
                steps {
                    script {
                        def parts = env.JOB_NAME.split('/')
                        env.REPO_NAME = parts[1]
                        env.BRANCH_NAME = java.net.URLDecoder.decode(parts[2], "UTF-8")
                        env.TAG = "${env.REPO_NAME}-${env.BUILD_NUMBER}"
                        env.DOCKER_IMAGE = "drdocker108/${env.REPO_NAME}:${env.TAG}"

                        echo "Repo: ${env.REPO_NAME}, Branch: ${env.BRANCH_NAME}, Tag: ${env.TAG}, ENV: ${params.ENVIRONMENT}"
                        sh "git ls-remote https://github.com/vinay2727/${env.REPO_NAME}.git"
                    }
                }
            }

            stage('Checkout Jenkins Config') {
                steps {
                    dir('central-config') {
                        git url: "${CONFIG_REPO}", branch: "${CONFIG_BRANCH}"
                        git url: 'https://github.com/vinay2727/jenkins.git', branch: 'main'
                    }
                }
            }

            stage('Source Checkout') {
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
            when {
                expression { params.ENVIRONMENT == 'qa' }
            }
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Docker Build & Push') {
            when {
                expression { params.ENVIRONMENT == 'qa' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        docker build -f central-config/Dockerfile -t ${DOCKERHUB_IMAGE}:${TAG} .
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKERHUB_IMAGE}:${TAG}
                        docker logout
                    '''
                }
            }
        }

        stage('Promote QA Image to Prod') {
            when {
                expression { params.ENVIRONMENT == 'prod' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    script {
                        echo "🔍 Getting image name from QA namespace pod..."
                        def qaImage = sh(
                            script: """
                                kubectl --kubeconfig=${KUBECONFIG} get pods -n qa -l app=${params.REPO_NAME} -o jsonpath='{.items[0].spec.containers[0].image}'
                            """,
                            returnStdout: true
                        ).trim()

                        if (!qaImage) {
                            error("❌ Could not retrieve image from QA namespace.")
                        }

                        echo "✅ Found QA image: ${qaImage}"

                        def prodTag = "${params.REPO_NAME}-${env.BUILD_NUMBER}"

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

return this
