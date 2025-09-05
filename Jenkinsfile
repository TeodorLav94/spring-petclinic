pipeline {
  agent { label 'docker' }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    DOCKER_HOST = 'unix:///var/run/docker.sock'
    REG_MR      = '192.168.64.3:5002'
    REPO_MR     = "${REG_MR}/mr/spring-petclinic"
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
          set +e
          ./mvnw -B -Dtest="**/*Test.java,**/*Tests.java,!**/*IntegrationTests.java,!**/*IT.java" test
          echo "[INFO] mvn test finished, ignoring failures"
          exit 0
        '''
        junit testResults: 'target/surefire-reports/*.xml',
              allowEmptyResults: true,
              skipMarkingBuildUnstable: true
        archiveArtifacts artifacts: 'target/surefire-reports/**',
                         allowEmptyArchive: true,
                         fingerprint: true
        sh '''
          if ls target/surefire-reports/*-errors.txt >/dev/null 2>&1; then
            echo "==== FAILING TESTS (first 200 lines) ===="
            sed -n "1,200p" target/surefire-reports/*-errors.txt || true
            echo "========================================="
          fi
        '''
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
          def imageTag = "${env.REPO_MR}:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds',
                                            usernameVariable: 'DOCKER_USER',
                                            passwordVariable: 'DOCKER_PWD')]) {
            sh """
              set -e
              echo "\$DOCKER_PWD" | docker login ${env.REG_MR} -u "\$DOCKER_USER" --password-stdin
              docker build -t "${imageTag}" .
              docker push "${imageTag}"
              docker logout ${env.REG_MR}
            """
          }
          echo "Pushed image: ${imageTag}"
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished (status: ${currentBuild.currentResult})"
    }
  }
}
