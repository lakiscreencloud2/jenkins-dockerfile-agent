## Android App Build with Jenkins Dockerfile Agent

Also with DinD + JCasC

This repository provides a minimal, repeatable setup to build an Android app inside Jenkins with Dockerfile-based Jenkins agent, also using Docker-in-Docker (dind) and Jenkins Configuration as Code (JCasC).

### What you get
- **One-command bring-up** of a Jenkins controller and a secure Docker daemon (dind)
- **JCasC-managed Jenkins** jenkins system config in `jenkins.yaml`
- **Jenkins Dockerfile agent build steps** defined in the Android project (`android-app/Jenkins`)
- **Gradle build** (`./gradlew clean assembleDebug`) and **APK archiving**
- Clear separation of concerns: Jenkins system config in `jenkins.yaml`; Android build logic and environment in `android-app/`

-----

## Repository layout

```text
.
├── docker-compose.yml          # Orchestrates Jenkins and dind
├── Dockerfile                  # Jenkins controller image (plugins + docker cli)
├── jenkins.yaml                # JCasC: Jenkins system + pipeline loading
└── android-app/
    ├── Dockerfile             # Android SDK/tools image for builds
    ├── Jenkinsfile            # Android app build Pipeline: sync, build, archive
    ├── gradlew                # Gradle Wrapper (used by the Pipeline)
    └── app/...                # Android app sources and Gradle config
```

-----

## How it works (high level)
- `docker-compose.yml` starts two containers:
  - `jenkins`: Jenkins controller (built from the root `Dockerfile`)
  - `docker`: Docker-in-Docker daemon serving TLS on 2376
- The controller connects to dind via `DOCKER_HOST=tcp://docker:2376` and mounts TLS certs.
- JCasC (`jenkins.yaml`) creates a Pipeline job that reads the Pipeline script from the mounted path `/workspace/android-app/Jenkinsfile`.
- The Pipeline’s build stage uses a `dockerfile` agent rooted at `android-app/` so Jenkins builds the Android image and runs Gradle inside it.

-----

## Prerequisites
- Docker Engine and Docker Compose
- Ports free on the host: `8080` (Jenkins), `2376` (dind)

-----

## Quick start
```bash
docker compose up -d --build
```
Open Jenkins at `http://localhost:8080`.

Default local user (defined by JCasC):
- Username: `admin`
- Password: `admin`

Generate an API token for `admin` in the UI (recommended), or use curl with a token to trigger the job (see below).

-----

## Triggering a build via API

1) Get a CSRF crumb (when using basic auth with a token):
```bash
TOKEN=YOUR_ADMIN_API_TOKEN
curl -sf --user admin:$TOKEN http://localhost:8080/crumbIssuer/api/json
```

2) Trigger the job:
```bash
CRUMB_JSON=$(curl -sf --user admin:$TOKEN http://localhost:8080/crumbIssuer/api/json)
CRUMB=$(echo "$CRUMB_JSON" | jq -r .crumb)
FIELD=$(echo "$CRUMB_JSON" | jq -r .crumbRequestField)
curl -X POST -s -o /dev/null -w "%{http_code}\n" \
  http://localhost:8080/job/dockerfile-agent-test/build \
  --user admin:$TOKEN -H "$FIELD: $CRUMB"
```

3) Fetch console output:
```bash
curl --user admin:$TOKEN \
  http://localhost:8080/job/dockerfile-agent-test/lastBuild/consoleText
```

Note: If you do a clean restart (remove `jenkins_home`), previously created tokens are invalid. Create a new token after each clean restart.

-----

## Clean restart
```bash
docker compose down -v
docker compose up -d --build
```

This removes the persisted `jenkins_home` volume and re-applies JCasC on boot.

-----

## Key configuration (with snippets)

### docker-compose.yml
```yaml
services:
  jenkins:
    build:
      context: .
    ports:
      - 8080:8080
    environment:
      - DOCKER_HOST=tcp://docker:2376
      - DOCKER_CERT_PATH=/certs/client
      - DOCKER_TLS_VERIFY=1
      - CASC_JENKINS_CONFIG=/var/jenkins_config/jenkins.yaml
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    volumes:
      - ./jenkins.yaml:/var/jenkins_config/jenkins.yaml:ro
      - jenkins_home:/var/jenkins_home
      - jenkins-docker-certs:/certs/client:ro
      - ./android-app:/workspace/android-app:ro

  docker:
    image: docker:dind
    ports:
      - 2376:2376
    privileged: true
    environment:
      - DOCKER_TLS_CERTDIR=/certs
    volumes:
      - jenkins-docker-certs:/certs/client
      - jenkins_home:/var/jenkins_home

volumes:
  jenkins_home:
  jenkins-docker-certs:
```

### Jenkins controller image (Dockerfile)
Installs required plugins (JCasC, Pipeline, Docker workflow, Job DSL) and Docker CLI for controller-side orchestration.
```dockerfile
FROM jenkins/jenkins:lts-jdk21
USER root
RUN apt-get update && apt-get install -y lsb-release \
 && curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc https://download.docker.com/linux/debian/gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y docker-ce-cli
RUN jenkins-plugin-cli --plugins \
  configuration-as-code credentials plain-credentials workflow-aggregator \
  docker-workflow git pipeline-model-definition github-branch-source job-dsl
USER jenkins
```

### JCasC (jenkins.yaml)
Defines the admin user and the Pipeline job that loads its script from the mounted `android-app/Jenkinsfile`.
```yaml
jenkins:
  systemMessage: "Jenkins configured automatically by JCasC."
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "admin"
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

unclassified:
  location:
    url: "http://localhost:8080/"

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

### Android build image (android-app/Dockerfile)
Sets up Android commandline tools and installs specific SDK components. Adjust versions via `ANDROID_BUILD_TOOLS_VERSION` and `ANDROID_SDK_VERSION` if needed.
```dockerfile
FROM openjdk:17-slim-bullseye
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools"
ENV ANDROID_SDK_TOOLS_REV="13114758"
ENV ANDROID_BUILD_TOOLS_VERSION="36.0.0"
ENV ANDROID_SDK_VERSION="36"
RUN apt-get update && apt-get -y install wget unzip socat xsltproc python3 zip sshpass \
 && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools
RUN wget --quiet -O ${ANDROID_SDK_ROOT}/android-sdk.zip \
    https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_REV}_latest.zip \
 && unzip -qq ${ANDROID_SDK_ROOT}/android-sdk.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
 && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
 && rm ${ANDROID_SDK_ROOT}/android-sdk.zip \
 && mkdir -p /root/.android \
 && touch /root/.android/repositories.cfg
RUN yes | sdkmanager --licenses > /dev/null \
 && yes | sdkmanager --update > /dev/null \
 && yes | sdkmanager "platform-tools" "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" "platforms;android-${ANDROID_SDK_VERSION}"
```

### Pipeline (android-app/Jenkinsfile)
Syncs sources into the workspace, builds inside a Dockerfile agent (running as root for tool installation and permissions), and archives the debug APK.
```groovy
pipeline {
  agent none
  stages {
    stage('Sync Android App Project') {
      agent any
      steps {
        sh 'rm -rf android-app && mkdir -p android-app'
        sh 'cp -r --no-preserve=mode,ownership,timestamps /workspace/android-app/. android-app/'
      }
    }
    stage('Build Android App and Archive APK') {
      agent {
        dockerfile {
          dir 'android-app'
          args '-u root:root'
        }
      }
      stages {
        stage('Build APK') {
          steps {
            dir('android-app') {
              sh 'chmod +x gradlew'
              sh './gradlew clean assembleDebug'
            }
          }
        }
        stage('Archive APK') {
          steps {
            archiveArtifacts artifacts: 'android-app/app/build/outputs/apk/debug/*.apk', followSymlinks: false
          }
        }
      }
    }
  }
}
```

-----

## Tips and troubleshooting
- **API tokens after clean restart**: removing `jenkins_home` invalidates tokens; create a new token in the UI.
- **Docker TLS errors**: ensure the controller uses `DOCKER_HOST=tcp://docker:2376` and mounts `jenkins-docker-certs` as in `docker-compose.yml`.
- **Gradle/SDK issues**: update `ANDROID_BUILD_TOOLS_VERSION` and `ANDROID_SDK_VERSION` in `android-app/Dockerfile` to match your project.
- **File permissions**: the Pipeline copies sources with `--no-preserve` and runs the build container as root (`-u root:root`) to avoid permission conflicts when writing build outputs and SDK caches.

-----

## Useful commands
```bash
# Start / rebuild
docker compose up -d --build

# Restart only Jenkins
docker compose restart jenkins

# View logs
docker logs -f jenkins-dockerfile-agent-jenkins-1 | sed -u '200q'

# Clean restart (removes data)
docker compose down -v && docker compose up -d --build
```

This setup gives you a clean, reproducible Android build pipeline with a jenkins Dockerfile agent and all configurations managed by code.
