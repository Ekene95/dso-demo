pipeline {
  agent {
    kubernetes {
      yamlFile 'build-agent.yaml'
      defaultContainer 'maven'
      idleMinutes 1
    }
  }

  environment {
    // Other environment variables
    ARGO_SERVER = '34.70.91.177:32101'
  }

  stages {
    stage('Build') {
      parallel {
        stage('Compile') {
          steps {
            container('maven') {
              sh 'mvn compile'
            }
          }
        }
      }
    }

    stage('Static Analysis') {
      parallel {
        stage('Unit Tests') {
          steps {
            container('maven') {
              sh 'mvn test'
            }
          }
        }

        stage('Generate SBOM') {
          steps {
            container('maven') {
              sh 'mvn org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom'
            }
          }
          post {
            success {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'target/bom.xml', fingerprint: true, onlyIfSuccessful: true
            }
          }
        }

        stage('SCA') {
          steps {
            container('maven') {
              catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                sh 'mvn org.owasp:dependency-check-maven:check'
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'target/dependency-check-report.html', fingerprint: true, onlyIfSuccessful: true
            }
          }
        }

        stage('OSS License Checker') {
          steps {
            container('licensefinder') {
              sh 'ls -al'
              sh '''#!/bin/bash --login
              /bin/bash --login
              rvm use default
              gem install license_finder
              license_finder
              '''
            }
          }
        }
      }
    }

    stage('Package') {
      parallel {
        stage('Create Jarfile') {
          steps {
            container('maven') {
              sh 'mvn package -DskipTests'
            }
          }
        }

        stage('OCI Image BnP') {
          steps {
            container('kaniko') {
              sh '''
                /kaniko/executor --verbosity debug -f `pwd`/Dockerfile -c `pwd` --insecure --skip-tls-verify --cache=true --destination=docker.io/kenzman/dsodemo:v1
              '''
            }
          }
        }
      }
    }

    stage('Image Analysis') {
      parallel {
        stage('Image Linting') {
          steps {
            container('docker-tools') {
              script {
                // Docker login before scanning with dockle
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                  sh 'docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD'
                }
                sh 'dockle --timeout 600s docker.io/kenzman/dsodemo:v1'
              }
            }
          }
        }

        stage('Image Scan') {
          steps {
            container('docker-tools') {
              script {
                // Docker login before scanning with trivy
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                  sh 'docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD'
                }
                sh 'trivy image --timeout 10m --exit-code 0 kenzman/dsodemo:v1'
              }
            }
          }
        }
      }
    }

      stage('Deploy to Dev') {
        environment {
          AUTH_TOKEN = credentials('argocd-jenkins-deployer-token')
        }
        steps {
          container('docker-tools') {
            sh 'docker run -t schoolofdevops/argocd-cli argocd app sync
dso-demo --insecure --server $ARGO_SERVER --auth-token $AUTH_TOKEN'
            sh 'docker run -t schoolofdevops/argocd-cli argocd app wait
dso-demo --health --timeout 300 --insecure --server $ARGO_SERVER
--auth-token $AUTH_TOKEN'
}
}
}

  }
}
