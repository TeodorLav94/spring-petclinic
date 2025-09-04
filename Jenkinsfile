pipeline {
  agent { label 'docker' }        // agentul tău care are docker
  options { timestamps() }

  environment {
    DOCKER_HOST = 'unix:///var/run/docker.sock'  // util în agenți dockerizați
  }

  stages {

    // -- MR / feature only ---------------------------------------------------
    stage('Checkstyle') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { env.GIT_BRANCH == 'origin/main' }
          }
        }
      }
      steps {
        sh 'chmod +x mvnw || true'
        // nu oprim build-ul pe abateri de stil
        sh './mvnw -B -DskipTests=false checkstyle:checkstyle || true'
        archiveArtifacts artifacts: 'target/checkstyle-result.xml',
                         fingerprint: true,
                         onlyIfSuccessful: false
        // dacă ai pluginul Warnings NG + Checkstyle:
        // recordIssues tools: [checkStyle(pattern: 'target/checkstyle-result.xml')]
      }
    }

    stage('Test (unit only)') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { env.GIT_BRANCH == 'origin/main' }
          }
        }
      }
      steps {
        sh 'chmod +x mvnw || true'
        // marchează stage FAIL dar build UNSTABLE (nu FAILURE) dacă pică
        catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
          // rulează doar testele unitare; exclude *IntegrationTests și *IT
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
      when {
        not {
          anyOf {
            branch 'main'
            expression { env.GIT_BRANCH == 'origin/main' }
          }
        }
      }
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B -DskipTests package'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    stage('Docker Build & Push (MR)') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { env.GIT_BRANCH == 'origin/main' }
          }
        }
      }
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageTag = "192.168.64.3:5002/mr/spring-petclinic:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PWD')]) {
            sh """
              set -e
              echo "\$DOCKER_PWD" | docker login 192.168.64.3:5002 -u "\$DOCKER_USER" --password-stdin
              docker build -t "${imageTag}" .
              docker push "${imageTag}"
              docker logout 192.168.64.3:5002
            """
          }
        }
      }
    }

    // -- MAIN only ------------------------------------------------------------
    stage('Docker Build & Push (MAIN)') {
      when {
        allOf {
          expression { env.CHANGE_ID == null } // nu pe PR-uri
          anyOf {
            branch 'main'                          // Multibranch
            expression { env.GIT_BRANCH == 'origin/main' } // job clasic
            expression { sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim() == 'main' } // fallback
          }
        }
      }
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageMain = "192.168.64.3:5002/main/spring-petclinic:${gitShort}"

          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PWD')]) {
            sh """
              set -e
              echo "\$DOCKER_PWD" | docker login 192.168.64.3:5002 -u "\$DOCKER_USER" --password-stdin
              docker build -t "${imageMain}" .
              docker push "${imageMain}"
              docker logout 192.168.64.3:5002
            """
          }
        }
      }
    }
  }
}
