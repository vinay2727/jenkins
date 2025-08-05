def call() {
    pipeline {
        agent any

        environment {
            KUBECONFIG = '/c/Users/rbih4/.kube/config'
            CONFIG_REPO = 'https://github.com/vinay2727/jenkins.git'
            CONFIG_BRANCH = 'main'
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

                        echo "📁 Repo: ${env.REPO_NAME}, Branch: ${env.BRANCH_NAME}, Tag: ${env.TAG}"
                    }
                }
            }

            stage('SAST Scan - SonarQube') {
                when {
                    expression {
                        return env.BRANCH_NAME.startsWith('release/')
                    }
                }
                steps {
                    withCredentials([
                        string(credentialsId: 'github-org-pat', variable: 'GITHUB_TOKEN'),
                        string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN'),
                        string(credentialsId: 'sonarqube-url', variable: 'SONAR_HOST_URL')
                    ]) {
                        script {
                            sh """
                                mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                                    -Dsonar.projectKey=${env.REPO_NAME} \
                                    -Dsonar.projectName=${env.REPO_NAME} \
                                    -Dsonar.host.url=$SONAR_HOST_URL \
                                    -Dsonar.login=$SONAR_TOKEN \
                                    -Dsonar.pullrequest.branch=${env.BRANCH_NAME} \
                                    -Dsonar.pullrequest.github.repository=vinay2727/${env.REPO_NAME} \
                                    -Dsonar.pullrequest.provider=GitHub
                            """

                            def ceTaskUrl = readFile('target/sonar/report-task.txt').split('\n')
                                .find { it.startsWith("ceTaskUrl=") }
                                ?.replace("ceTaskUrl=", "")
                                ?.trim()

                            echo "🔍 Waiting for SonarQube analysis to complete..."
                            sleep(time: 10, unit: 'SECONDS')

                            def taskStatus = "PENDING"
                            def analysisId = ""
                            while (taskStatus == "PENDING" || taskStatus == "IN_PROGRESS") {
                                def ceResponse = sh(
                                    script: "curl -s -u $SONAR_TOKEN: ${ceTaskUrl}",
                                    returnStdout: true
                                ).trim()
                                def json = readJSON text: ceResponse
                                taskStatus = json.task.status
                                analysisId = json.task.analysisId ?: ""
                                if (taskStatus == "PENDING" || taskStatus == "IN_PROGRESS") {
                                    sleep(time: 3, unit: 'SECONDS')
                                }
                            }

                            if (!analysisId) {
                                error("❌ Failed to retrieve analysis ID from SonarQube.")
                            }

                            def measuresResponse = sh(
                                script: "curl -s -u $SONAR_TOKEN: \"$SONAR_HOST_URL/api/measures/component?component=${env.REPO_NAME}&metricKeys=coverage\"",
                                returnStdout: true
                            ).trim()

                            def jsonMeasures = readJSON text: measuresResponse
                            def coverageStr = jsonMeasures.component.measures[0].value
                            def coverage = coverageStr.toFloat()

                            echo "📊 SonarQube Code Coverage: ${coverage}%"

                            if (coverage < 80.0) {
                                error("❌ Code coverage is below 80%. Pipeline aborted.")
                            } else {
                                echo "✅ Code coverage is sufficient. Proceeding..."
                            }
                        }
                    }
                }
            }

            stage('Fetch PR Label') {
                when {
                    expression {
                        return env.BRANCH_NAME.startsWith('release/')
                    }
                }
                steps {
                    withCredentials([string(credentialsId: 'Github-PAT', variable: 'GITHUB_TOKEN')]) {
                        script {
                            def prLabels = sh(
                                script: """
                                    curl -s -H "Authorization: token $GITHUB_TOKEN" \
                                    https://api.github.com/repos/vinay2727/${env.REPO_NAME}/pulls | \
                                    jq -r '.[] | select(.head.ref == "${env.BRANCH_NAME}") | .labels[].name'
                                """,
                                returnStdout: true
                            ).trim()

                            if (prLabels.contains('env/qa')) {
                                env.TARGET_ENV = 'qa'
                            } else if (prLabels.contains('env/prod')) {
                                env.TARGET_ENV = 'prod'
                            } else {
                                error "❌ No valid deployment label found (env/qa, env/prod)"
                            }

                            echo "🏷 Deployment label identified: ${env.TARGET_ENV}"
                        }
                    }
                }
            }

            stage('Approval') {
                when { expression { env.TARGET_ENV == 'prod' } }
                steps {
                    script {
                        timeout(time: 15, unit: 'MINUTES') {
                            input message: "Approve deployment to PROD?", ok: 'Proceed', submitter: 'vinay,mohan'
                        }
                    }
                }
            }

            stage('Checkout Config') {
                steps {
                    dir('central-config') {
                        git url: "${CONFIG_REPO}", branch: "${CONFIG_BRANCH}", credentialsId: 'Github-PAT'
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
                steps {
                    sh 'mvn clean package -DskipTests'
                }
            }

            stage('Docker Build & Push') {
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

            stage('Deploy to Environment') {
                steps {
                    sh """
                        echo "🔧 Setting KUBECONFIG..."
                        kubectl --kubeconfig=${KUBECONFIG} config use-context minikube || true

                        echo "📦 Ensuring namespace: ${env.TARGET_ENV}"
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${env.TARGET_ENV} --dry-run=client -o yaml | kubectl apply -f -

                        echo "🚀 Deploying image: ${DOCKER_IMAGE} to ${env.TARGET_ENV} namespace..."
                        sed "s|<IMAGE_TAG>|${TAG}|g; s|<REPO_NAME>|${env.REPO_NAME}|g; s|<ENV>|${env.TARGET_ENV}|g" central-config/k8s-deployment.yaml | \
                        kubectl --kubeconfig=${KUBECONFIG} apply -n ${env.TARGET_ENV} -f -
                    """
                }
            }
        }
    }
}
return this
