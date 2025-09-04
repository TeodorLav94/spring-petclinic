pipeline {
  agent { label 'docker' }
  options { timestamps() }

  environment {
    DOCKER_HOST = 'unix:///var/run/docker.sock'
    REG_MR   = '192.168.64.3:5002'
    REG_MAIN = '192.168.64.3:5001'
    REPO_MR   = "${REG_MR}/mr/spring-petclinic"        // fără env.
    REPO_MAIN = "${REG_MAIN}/main/spring-petclinic"
  }

  stages {

    // -- DEBUG: vezi exact ce vede Jenkins (șterge după ce verifici) --
    stage('Debug branch vars') {
      steps {
        sh '''
          echo "BRANCH_NAME=$BRANCH_NAME"
          echo "GIT_BRANCH=$GIT_BRANCH"
          echo "CHANGE_ID=$CHANGE_ID"
          echo "CHANGE_BRANCH=$CHANGE_BRANCH"
          echo "CHANGE_TARGET=$CHANGE_TARGET"
          echo "git HEAD branch=$(git rev-parse --abbrev-ref HEAD || true)"
        '''
      }
    }

    // ---------- FEATURE / MR ONLY ----------
    stage('Checkstyle') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { (env.GIT_BRANCH ?: '').endsWith('/main') || (env.GIT_BRANCH ?: '') == 'main' }
          }
        }
      }
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B -DskipTests=false checkstyle:checkstyle || true'
        archiveArtifacts artifacts: 'target/checkstyle-result.xml', fingerprint: true, onlyIfSuccessful: false
      }
    }

    stage('Test (unit only)') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { (env.GIT_BRANCH ?: '').endsWith('/main') || (env.GIT_BRANCH ?: '') == 'main' }
          }
        }
      }
      steps {
        sh 'chmod +x mvnw || true'
        catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
          sh './mvnw -B -Dtest="**/*Test.java,**/*Tests.java,!**/*IntegrationTests.java,!**/*IT.java" test'
        }
        junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
        archiveArtifacts artifacts: 'target/surefire-reports/**', allowEmptyArchive: true, fingerprint: true
      }
    }

    stage('Build (skip tests)') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { (env.GIT_BRANCH ?: '').endsWith('/main') || (env.GIT_BRANCH ?: '') == 'main' }
          }
        }
      }
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B -DskipTests package'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    stage('Docker Build & Push (MR -> :5002)') {
      when {
        not {
          anyOf {
            branch 'main'
            expression { (env.GIT_BRANCH ?: '').endsWith('/main') || (env.GIT_BRANCH ?: '') == 'main' }
          }
        }
      }
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageTag = "${REPO_MR}:${gitShort}"
          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PWD')]) {
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

    // ---------- MAIN ONLY ----------
    stage('Docker Build & Push (MAIN -> :5001)') {
      when {
        allOf {
          expression { env.CHANGE_ID == null } // nu pe PR-uri
          anyOf {
            branch 'main'  // Multibranch clasic
            expression { (env.BRANCH_NAME ?: '') == 'main' }
            expression { (env.GIT_BRANCH   ?: '').endsWith('/main') || (env.GIT_BRANCH ?: '') == 'main' }
            expression { sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim() == 'main' }
          }
        }
      }
      steps {
        script {
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def imageMain = "${REPO_MAIN}:${gitShort}"
          withCredentials([usernamePassword(credentialsId: 'docker-reg-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PWD')]) {
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
