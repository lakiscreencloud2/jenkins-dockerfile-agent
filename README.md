## Android App Build & Test with Jenkins Dockerfile Agent

This repository provides a minimal, repeatable setup to build and test an Android app inside Jenkins using a Dockerfile-based agent. It leverages Docker-in-Docker (DinD) and Jenkins Configuration as Code (JCasC) and includes the ability to run connected Android tests against an ADB server running on the host machine.

### What you get ✨
- **One-command bring-up** of a Jenkins controller and a secure Docker daemon (DinD).
- **JCasC-managed Jenkins** with all system configuration defined in `jenkins/jenkins.yaml`.
- **Dockerfile-based agents** where the Android build environment is defined right next to the app source code.
- **A complete pipeline** that builds the app, archives the APK, and conditionally runs instrumentation tests.
- **Host ADB integration** using `socat` to proxy commands from the agent container to a physical device or emulator for running tests.
- **Clear separation of concerns**: Jenkins system config in `jenkins/`; Android build logic in `android-app/`.

---

## Repository Layout

```text
.
├── docker-compose.yml          # Orchestrates Jenkins and DinD services
├── jenkins/
│   ├── Dockerfile              # Jenkins controller image (plugins + Docker CLI)
│   └── jenkins.yaml            # JCasC: Jenkins system + pipeline job definition
└── android-app/
    ├── Dockerfile              # Android SDK/tools image for build agents
    ├── Jenkinsfile             # The build, test, and archive pipeline script
    ├── gradlew                 # Gradle Wrapper (used by the pipeline)
    └── app/                    # Android app sources and Gradle config
````

-----

## How it Works ⚙️

1.  **`docker-compose.yml`** starts two containers: `jenkins` (the controller) and `docker` (a DinD daemon). They communicate over a shared Docker network.
2.  The `jenkins` controller is configured via environment variables to connect to the `docker` daemon using TLS, enabling it to build and run other Docker containers.
3.  On startup, Jenkins uses the **JCasC plugin** to automatically apply the configuration from `jenkins/jenkins.yaml`. This creates a pipeline job named `dockerfile-agent-test`.
4.  The pipeline job reads its definition from `android-app/Jenkinsfile`, which is mounted into the controller.
5.  When the pipeline runs, the 'Build, Test & Archive' stage uses a `dockerfile` agent. Jenkins builds a temporary agent image from `android-app/Dockerfile` and runs the build steps inside a container based on that image.
6.  Inside the agent container, a `socat` process is started to forward ADB requests from the container's port `5037` to the host machine's ADB server via `host.docker.internal:5037`, allowing Gradle to run `connectedDebugAndroidTest` on any connected device or emulator.

-----

## Prerequisites

  - Docker Engine and Docker Compose
  - An ADB server running on your host machine and listening on all network interfaces.
  - An Android device or emulator connected and authorized with the host ADB server.
  - Ports `8080` (Jenkins) and `2376` (DinD) must be free on the host.

-----

## Quick Start

### 1. Prepare and Start the Host ADB Server

This project includes a script to download the correct Android platform tools and start the ADB server configured to accept network connections.

First, make the script executable:

```bash
chmod +x start-host-adb-server.sh
```

Now, run the script:

```bash
./start-host-adb-server.sh
```

The script will download platform-tools into a local `android-platform-tools` directory (if not already present) and then start the ADB server.

### 2. Launch Jenkins

```bash
docker compose up -d --build
```

Open Jenkins in your browser at `http://localhost:8080`.

Log in with the default credentials (defined in `jenkins.yaml`):

  - **Username**: `admin`
  - **Password**: `admin`

Run the `dockerfile-agent-test` job. If a device is connected and recognized by `adb devices`, the test stage will run. Otherwise, it will be skipped automatically.

-----

## Key Configuration Snippets

### docker-compose.yml

Orchestrates the Jenkins controller and the Docker-in-Docker daemon. Note the volume mounts that provide the configuration files and allow the services to communicate.

```yaml
services:
  jenkins:
    build:
      context: ./jenkins
    ports:
      - 8080:8080
    environment:
      - DOCKER_HOST=tcp://docker:2376
      # ... other env vars
    volumes:
      - ./jenkins/jenkins.yaml:/var/jenkins_config/jenkins.yaml:ro
      - jenkins_home:/var/jenkins_home
      - jenkins-docker-certs:/certs/client:ro
      - ./android-app:/workspace/android-app:ro
    networks:
      - jenkins

  docker:
    image: docker:dind
    ports:
      - 2376:2376
    # ... other config
    networks:
      - jenkins
```

### JCasC (jenkins/jenkins.yaml)

Configures the Jenkins instance and creates our pipeline job. The job is defined to load its script directly from the mounted `Jenkinsfile`.

```yaml
jobs:
  - script: >
      pipelineJob('dockerfile-agent-test') {
        description('Android build pipeline using android-app/Jenkinsfile with Gradle build and APK archiving.')
        definition {
          cps {
            script(new File('/workspace/android-app/Jenkinsfile').text)
            sandbox()
          }
        }
      }
```

### Android Agent (android-app/Dockerfile)

Defines the entire build environment for our Android app, including the Java version, Android SDK, and build tools.

```dockerfile
FROM openjdk:17-slim-bullseye

ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools"
# ... other SDK versions
RUN apt-get update && \
    apt-get -y install wget unzip socat && \
    # ... SDK setup commands

# Use sdkmanager to accept licenses and install components
RUN yes | sdkmanager --licenses > /dev/null && \
    yes | sdkmanager --update > /dev/null && \
    yes | sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" "platforms;android-${ANDROID_SDK_VERSION}"
```

### Pipeline (android-app/Jenkinsfile)

This declarative pipeline defines the CI/CD flow. The key features are:

  - **`agent { dockerfile { ... } }`**: Tells Jenkins to build and use an agent from the specified `Dockerfile`.
  - **`args '-u root:root --network host'`**: Runs the agent container as `root` to avoid permission issues and connects it to the host's network, which is essential for `socat` to reach `host.docker.internal`.
  - **`socat` proxy**: A dedicated stage starts a proxy to forward ADB requests to the host.
  - **Conditional Test Stage**: The `when` block checks for connected devices before running tests.
  - **`post { always { ... } }`**: A robust cleanup block ensures the `socat` process is killed and workspace permissions are fixed after every run.

```groovy
pipeline {
    agent none
    environment {
        APP_DIR = 'android-app'
    }
    stages {
        stage('Preparation') { /* ... clean workspace and copy files ... */ }

        stage('Build, Test & Archive') {
            agent {
                dockerfile {
                    dir env.APP_DIR
                    args '-u root:root --network host'
                }
            }
            stages {
                stage('Build APK') {
                    steps {
                        dir(env.APP_DIR) {
                            sh 'chmod +x gradlew && ./gradlew clean assembleDebug'
                        }
                    }
                }
                stage('Setup ADB Proxy') {
                    steps {
                        sh 'socat TCP-LISTEN:5037,fork TCP:host.docker.internal:5037 & echo $! > socat.pid'
                    }
                }
                stage('Run Instrumented Tests') {
                    when {
                        expression {
                            def adbCheck = sh(script: 'adb devices | grep -w "device"', returnStatus: true)
                            return adbCheck == 0
                        }
                    }
                    steps {
                        dir(env.APP_DIR) {
                            sh './gradlew connectedDebugAndroidTest --info --stacktrace'
                        }
                    }
                }
                stage('Archive Artifacts') { /* ... archive the APK ... */ }
            }
            post {
                always {
                    script {
                        echo 'Performing post-build cleanup...'
                        sh "if [ -f socat.pid ]; then kill \$(cat socat.pid); rm socat.pid; fi"
                        // ... permission fixes
                    }
                }
            }
        }
    }
}
```

-----

## Tips and Troubleshooting

  - **No Device Found**: If the 'Run Instrumented Tests' stage is always skipped, ensure your host ADB server was started with `adb -a server nodaemon` and that your host machine's firewall is not blocking connections to port `5037`. Running `adb devices` on your host should show your device.
  - **`host.docker.internal`**: This is a special DNS name provided by Docker that resolves to the internal IP address of the host, making the host's ADB server reachable from within a container.
  - **Clean Restart**: To reset your Jenkins instance completely, run `docker compose down -v`. This removes the `jenkins_home` volume, deleting all job history and credentials. Jenkins will be reconfigured from `jenkins.yaml` on the next startup.
