pipeline {
  agent { label 'docker' }   // rulează pe agentul tău existent

  options { timestamps() }

  stages {
    stage('Checkstyle') {
      when { not { branch 'main' } }   // rulează doar pe branch-uri ≠ main (adică MR/feature)
      steps {
        sh 'chmod +x mvnw || true'
        // rulează checkstyle; nu oprim build-ul dacă sunt abateri
        sh './mvnw -B -DskipTests=false checkstyle:checkstyle || true'

        // publicăm raportul ca artifact accesibil din UI-ul build-ului
        archiveArtifacts artifacts: 'target/checkstyle-result.xml',
                         fingerprint: true,
                         onlyIfSuccessful: false

        // (opțional) dacă ai pluginul Warnings NG + Checkstyle în Jenkins:
        // recordIssues tools: [checkStyle(pattern: 'target/checkstyle-result.xml')]
      }
    }
    stage('Test (unit only)') {
      when { not { branch 'main' } }
      steps {
        sh 'chmod +x mvnw || true'
        catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
          // rulează doar testele unitare; excludem *IntegrationTests și *IT
          sh './mvnw -B -Dtest="**/*Test.java,**/*Tests.java,!**/*IntegrationTests.java,!**/*IT.java" test'
        }
        junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
        archiveArtifacts artifacts: 'target/surefire-reports/**', allowEmptyArchive: true, fingerprint: true
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
      when { not { branch 'main' } }   // doar pe MR/feature
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B -DskipTests package'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }
    stage('Docker Build & Push (MR)') {
      when { not { branch 'main' } }   // rulează doar pe MR/feature
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageTag = "192.168.64.3:5002/mr/spring-petclinic:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PWD')]) {
            sh """
              echo "$DOCKER_PWD" | docker login 192.168.64.3:5002 -u "$DOCKER_USER" --password-stdin
              docker build -t "${imageTag}" .
              docker push "${imageTag}"
              docker logout 192.168.64.3:5002
            """
          }
        }
      }
    }
  }
}
