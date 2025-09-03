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
    stage('Test') {
      when { not { branch 'main' } }   // doar pe MR/feature
      steps {
        sh 'chmod +x mvnw || true'
        sh './mvnw -B test'
         // Publică rapoartele JUnit în Jenkins
        junit 'target/surefire-reports/*.xml'
      }
    }
  }
}
