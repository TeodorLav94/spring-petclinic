pipeline {
  agent { label 'docker' }
  options { timestamps() }

  environment {
    DOCKER_HOST = 'unix:///var/run/docker.sock'
    REG_MR   = '192.168.64.3:5002'
    REPO_MR  = "${REG_MR}/mr/spring-petclinic"
  }

  stages {
    stage('Checkstyle') {
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B -DskipTests=false checkstyle:checkstyle || true'
        archiveArtifacts artifacts: 'target/checkstyle-result.xml',
                         fingerprint: true,
                         onlyIfSuccessful: false
      }
    }

    stage('Test (unit only)') {
      steps {
        sh 'chmod +x mvnw || true'
        sh '''
          set -e
          printf "**/*IT.java\n**/*ITCase.java\n**/*IntegrationTest.java\n**/*IntegrationTests.java\n" > ci-excludes.txt
          ./mvnw -B -Dsurefire.excludesFile=ci-excludes.txt -DfailIfNoTests=false test
        '''
        junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
        archiveArtifacts artifacts: 'target/surefire-reports/**', allowEmptyArchive: true, fingerprint: true
      }
    }

    stage('Build (skip tests)') {
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B -DskipTests package'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    stage('Docker Build & Push (MR -> :5002)') {
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageTag = "${REPO_MR}:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds',
                                           usernameVariable: 'DOCKER_USER',
                                           passwordVariable: 'DOCKER_PWD')]) {
            sh """
              set -e
              echo "\$DOCKER_PWD" | docker login ${REG_MR} -u "\$DOCKER_USER" --password-stdin
              docker build -t "${imageTag}" .
              docker push "${imageTag}"
              docker logout ${REG_MR}
            """
          }
        }
      }
    }
  }
}
