pipeline {
  agent { label 'docker' }
  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    DOCKERHUB_REPO = 'tlavric/petclinic'
    IMAGE_BASE     = "${DOCKERHUB_REPO}"

    DB_USER        = "petclinicuser"
  }

  stages {
    stage('Clean Workspace') {
      steps { deleteDir() }
    }

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Compute Build Context') {
      steps {
        script {
          env.GIT_SHA       = sh(returnStdout: true, script: 'git rev-parse --short=8 HEAD').trim()
          env.IS_PR         = (env.CHANGE_ID?.trim()) ? "true" : "false"
          env.IS_MAIN       = (env.BRANCH_NAME == 'main') ? "true" : "false"
          env.DEPLOY_ALLOWED = (env.IS_MAIN == "true" && env.IS_PR != "true") ? "true" : "false"

          echo "BRANCH_NAME=${env.BRANCH_NAME}"
          echo "CHANGE_ID=${env.CHANGE_ID}"
          echo "GIT_SHA=${env.GIT_SHA}"
          echo "IS_PR=${env.IS_PR}, IS_MAIN=${env.IS_MAIN}, DEPLOY_ALLOWED=${env.DEPLOY_ALLOWED}"
        }
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

    stage('Docker Build & Push (commit SHA tag)') {
      // rulează pe orice branch + PR (artefact identificabil)
      steps {
        script {
          def imageTag = "${IMAGE_BASE}:${env.GIT_SHA}"

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

          echo "Pushed image: ${imageTag}"
        }
      }
    }

    stage('Semantic Versioning & Git Tag (main only)') {
      when {
        allOf {
          branch 'main'
          expression { return env.CHANGE_ID == null } // nu tag-ui din PR build
        }
      }
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: 'github-creds',
                                            usernameVariable: 'GIT_USER',
                                            passwordVariable: 'GIT_TOKEN')]) {

            sh """
              set -e
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

    stage('Docker Build & Push (release tag - main only)') {
      when {
        allOf {
          branch 'main'
          expression { return env.CHANGE_ID == null }
        }
      }
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

          echo "Pushed release image: ${imageTag}"
        }
      }
    }

    stage('Load Infra Outputs (from infra job artifact)') {
      when { expression { return env.DEPLOY_ALLOWED == "true" } }
      steps {
        copyArtifacts(
          projectName: 'infra-terraform',
          selector: [$class: 'LastCompletedBuildSelector']
          filter: 'infra-outputs.env'
        )

        script {
          def props = readProperties file: 'infra-outputs.env'
          env.APP_VM_IP = props['APP_VM_IP']
          env.APP_URL   = props['APP_URL']
          env.DB_HOST   = props['DB_HOST']

          echo "Loaded from artifact:"
          echo "  APP_VM_IP=${env.APP_VM_IP}"
          echo "  APP_URL=${env.APP_URL}"
          echo "  DB_HOST=${env.DB_HOST}"
        }
      }
    }


    stage('Deploy to App VM (manual, main only)') {
      when {
        expression { return env.DEPLOY_ALLOWED == "true" }
      }
      steps {
        script {
          input message: "Deploy version ${env.APP_VERSION} to production?"

          withCredentials([string(credentialsId: 'petclinic-db-password', variable: 'DB_PASSWORD')]) {
            sh """
              set -e
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

  post {
    always {
      sh 'docker logout || true'
    }
  }
}
