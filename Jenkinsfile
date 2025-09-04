pipeline {
  agent { label 'docker' }
  options { timestamps() }

  environment {
    DOCKER_HOST = 'unix:///var/run/docker.sock'
    REG_MAIN  = '192.168.64.3:5001'
    REPO_MAIN = "${REG_MAIN}/main/spring-petclinic"
  }

  stages {
    stage('Docker Build & Push (MAIN -> :5001)') {
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageMain = "${REPO_MAIN}:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds',
                                           usernameVariable: 'DOCKER_USER',
                                           passwordVariable: 'DOCKER_PWD')]) {
            sh """
              set -e
              echo "\$DOCKER_PWD" | docker login ${REG_MAIN} -u "\$DOCKER_USER" --password-stdin
              docker build -t "${imageMain}" .
              docker push "${imageMain}"
              docker logout ${REG_MAIN}
            """
          }
        }
      }
    }
  }
}
