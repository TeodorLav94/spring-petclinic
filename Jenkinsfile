pipeline {
  agent { label 'docker' }
  options { timestamps() }

  environment {
    DOCKERHUB_REPO = 'tlavric/petclinic'
    IMAGE_BASE     = "${DOCKERHUB_REPO}"
    DB_USER        = "petclinicuser"   
  }

  stages {
    stage('Clean Workspace') {
          steps {
            deleteDir()
          }
        }

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Static Code Analysis') {
      steps {
        sh 'mvn -B -DskipTests=true verify'
      }
    }

    stage('Tests') {
      steps {
        sh 'mvn -B test'
      }
    }

    stage('Build Jar') {
      steps {
        sh 'mvn -B package -DskipTests'
      }
    }

    stage('Docker Build & Push (commit tag)') {
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageTag = "${IMAGE_BASE}:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                            usernameVariable: 'DOCKERHUB_USER',
                                            passwordVariable: 'DOCKERHUB_TOKEN')]) {

            sh """
              set -e

              echo "Using image tag: ${imageTag}"

              echo "\${DOCKERHUB_TOKEN}" | docker login -u "\${DOCKERHUB_USER}" --password-stdin

              docker build -t ${imageTag} .
              docker push ${imageTag}
            """
          }
        }
      }
    }

    stage('Semantic Versioning & Git Tag') {
    steps {
      script {
        withCredentials([usernamePassword(credentialsId: 'github-creds',
                                          usernameVariable: 'GIT_USER',
                                          passwordVariable: 'GIT_TOKEN')]) {

          sh """
            git config user.email "jenkins@ci.local"
            git config user.name "Jenkins CI"

            git remote set-url origin https://${GIT_USER}:${GIT_TOKEN}@github.com/TeodorLav94/spring-petclinic.git
            git fetch --tags

            python3 scripts/bump_version.py
          """
        }

        env.APP_VERSION = sh(returnStdout: true, script: 'cat .version').trim()
        echo "New app version: ${env.APP_VERSION}"
      }
    }
  }


    stage('Docker Build & Push (release tag)') {
      steps {
        script {
          def versionTag = env.APP_VERSION
          def imageTag   = "${IMAGE_BASE}:${versionTag}"

          withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                            usernameVariable: 'DOCKERHUB_USER',
                                            passwordVariable: 'DOCKERHUB_TOKEN')]) {

            sh """
              set -e

              echo "\${DOCKERHUB_TOKEN}" | docker login -u "\${DOCKERHUB_USER}" --password-stdin

              docker build -t ${imageTag} .
              docker push ${imageTag}
            """
          }
        }
      }
    }

    stage('Checkout Infra (for Terraform outputs)') {
      steps {
        dir('infra-terraform') {
          git url: 'https://github.com/TeodorLav94/infra-terrafrom.git', branch: 'main'
        }
      }
    }

    stage('Load Infra Outputs') {
      steps {
        script {
          dir('infra-terraform/jenkins') {
            sh 'terraform init -input=false'

            env.DB_HOST = sh(
              returnStdout: true,
              script: 'terraform output -raw db_public_ip'
            ).trim()
          }

          dir('infra-terraform/app') {
            sh 'terraform init -input=false'

            env.APP_VM_IP = sh(
              returnStdout: true,
              script: 'terraform output -raw app_vm_internal_ip'
            ).trim()

            env.APP_URL = sh(
              returnStdout: true,
              script: 'terraform output -raw app_url'
            ).trim()
          }

          echo "Loaded infra outputs:"
          echo "  APP_VM_IP = ${env.APP_VM_IP}"
          echo "  DB_HOST   = ${env.DB_HOST}"
          echo "  APP_URL   = ${env.APP_URL}"
        }
      }
    }

    stage('Deploy to App VM') {
     // when { branch 'main' }   
      steps {
        script {
          input message: "Deploy version ${env.APP_VERSION} to production?"

          withCredentials([string(credentialsId: 'petclinic-db-password', variable: 'DB_PASSWORD')]) {
            sh """
              ssh -o StrictHostKeyChecking=no tlavric@${APP_VM_IP} '
                docker stop petclinic || true
                docker rm petclinic || true

                docker pull ${IMAGE_BASE}:${APP_VERSION}

                docker run -d --name petclinic \
                    -e SPRING_DATASOURCE_URL="jdbc:mysql://${DB_HOST}:3306/petclinic" \
                    -e SPRING_DATASOURCE_USERNAME="${DB_USER}" \
                    -e SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD}" \
                    -e SPRING_JPA_HIBERNATE_DDL_AUTO=update \
                    -p 8080:8080 \
                    ${IMAGE_BASE}:${APP_VERSION}

                echo "App available at: ${APP_URL}"
              '
            """
          }
        }
      }
    }

  }
}
