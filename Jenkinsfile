pipeline{
    agent any
    stages {
        stage('checkout'){
            steps{
                git branch : 'main',
                url : 'https://github.com/ahmmedtarek/devops-eks-project.git'
                
            }
        }
        stage('test'){
            steps{
                sh 'python3 -m pytest'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarQube'

                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=devops-eks-project \
                            -Dsonar.sources=app
                        """
                    }
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('build'){
            steps{
                sh 'docker build -t app:${BUILD_NUMBER} .'
            }
        }
        stage('Scan with trivy'){
            steps{
                sh '''
                 trivy image \
                 --severity CRITICAL \
                 --exit-code 1 \
                 app:${BUILD_NUMBER}
             '''
            }
        }
        stage('test the image'){
            steps{
                sh """
                docker rm -f test-container || true
                docker run -d --name test-container -p 5000:5000 app:${BUILD_NUMBER}
                sleep 3
                curl http://localhost:5000
                docker rm -f test-container
                """
            }
        }
        stage('push the image to ecr'){
            steps{
                sh """
                aws ecr get-login-password --region eu-north-1 | \
                docker login --username AWS --password-stdin \
                305018987435.dkr.ecr.eu-north-1.amazonaws.com
                docker tag app:${BUILD_NUMBER} 305018987435.dkr.ecr.eu-north-1.amazonaws.com/app:${BUILD_NUMBER}
                docker push 305018987435.dkr.ecr.eu-north-1.amazonaws.com/app:${BUILD_NUMBER}
                """
            }
        }
        stage('Update GitOps Repo') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh '''
                        rm -rf devops-eks-gitops || true

                        git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/ahmmedtarek/devops-eks-gitops.git

                        cd devops-eks-gitops

                        sed -i "s|image: .*|image: 305018987435.dkr.ecr.eu-north-1.amazonaws.com/app:${BUILD_NUMBER}|" k8s/deployment-app.yaml

                        git config user.email "ahmmedtarek70@gmail.com"
                        git config user.name "ahmmedtarek"

                        git add k8s/deployment-app.yaml
                        git commit -m "Update image to ${BUILD_NUMBER}"
                        git push origin main
                    '''
                }
            }
        }
    }
}