pipeline {
  agent { label 'docker' }
  options { timestamps() }

  environment {
    PROJECT_ID   = 'gd-gcp-internship-devops'
    GAR_REGION   = 'europe-west1'
    GAR_REPO     = 'petclinic'
    IMAGE_NAME   = 'spring-petclinic'

    // Folositor: nume complet imagine
    IMAGE_BASE = "${GAR_REGION}-docker.pkg.dev/${PROJECT_ID}/${GAR_REPO}/${IMAGE_NAME}"
    
     // App VM (Terraform output)
    APP_VM_IP    = "34.140.59.138" 

    // Cloud SQL (Terraform output)
    DB_PRIVATE_IP = "10.20.0.3"
    DB_USER       = "petclinicuser"

    APP_URL       = "http://34.54.225.119"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Static Code Analysis') {
      steps {
        sh 'mvn -B verify -DskipTests=false' 
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

        sh """
          set -e

          echo "Using image tag: ${imageTag}"

          # Arată cine e autentificat, ca debug
          gcloud auth list

          # Configurează Docker să folosească Artifact Registry cu SA-ul atașat VM-ului
          gcloud auth configure-docker ${GAR_REGION}-docker.pkg.dev -q

          # Build imagine Docker
          docker build -t ${imageTag} .

          # Push imagine în Artifact Registry
          docker push ${imageTag}
        """
      }
    }
  }

    // ---------- DOAR PENTRU MAIN DE AICI ÎN JOS ----------

    stage('Semantic Versioning & Git Tag') {
    when { branch 'main' }
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
      when { branch 'main' }
      steps {
        script {
          def versionTag = env.APP_VERSION  // ex: v1.3.0
          def imageTag   = "${IMAGE_BASE}:${versionTag}"

          sh """
            set -e
            # ne asigurăm că docker e configurat pt Artifact Registry și aici
            gcloud auth configure-docker ${GAR_REGION}-docker.pkg.dev -q

            docker build -t ${imageTag} .
            docker push ${imageTag}
          """
        }
      }
    }

    stage('Deploy to App VM') {
      when { branch 'main' }
      steps {
        script {
          // Input manual – cineva trebuie să apese "Proceed"
          input message: "Deploy version ${env.APP_VERSION} to production?"

          // Presupunem că ai un credential SSH cu id 'app-vm-ssh'
          // și că ai APP_VM_IP, DB_PRIVATE_IP, DB_USER, DB_PASSWORD în credențiale/env vars
          def appVmIp = env.APP_VM_IP
          def sshUser = "tlavric" 

          sshagent(credentials: ['app-vm-ssh']) {
            withCredentials([string(credentialsId: 'petclinic-db-password', variable: 'DB_PASSWORD')]) {

            sh """
              ssh -o StrictHostKeyChecking=no ${sshUser}@${appVmIp} '
                docker stop petclinic || true
                docker rm petclinic || true

                docker pull ${IMAGE_BASE}:${APP_VERSION}

                docker run -d --name petclinic \
                  -e SPRING_DATASOURCE_URL="jdbc:mysql://${DB_PRIVATE_IP}:3306/petclinic" \
                  -e SPRING_DATASOURCE_USERNAME="${DB_USER}" \
                  -e SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD}" \
                  -p 8080:8080 \
                  ${IMAGE_BASE}:${APP_VERSION}

                echo "Aplicatia este disponibila la: ${APP_URL}"
              '
            """
            }
          }
        }
      }
    }
  }
}
