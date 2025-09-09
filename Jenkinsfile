pipeline {
    // 💻 Use a Dockerfile from the 'build' directory as the execution environment
    agent {
        dockerfile {
            dir 'build'
        }
    }
    stages {
        stage('List Files in Container') {
            steps {
                echo '🚀 Running inside our custom-built container!'
                // This command executes inside the container defined by build/Dockerfile
                sh 'ls -l'
            }
        }
    }
}
