# Docker Compose Setup for Android CI/CD

This document explains the components defined in the `docker-compose.yml` file and provides instructions for managing the Jenkins environment.

## Services

Our `docker-compose.yml` orchestrates two main services that work together to create a flexible and isolated CI/CD environment.

### 1\. The Jenkins Service (`jenkins`)

This is the main Jenkins controller where you'll manage jobs, view builds, and configure system settings.

  * **Build Context:** It's built from the `./Dockerfile`, creating a custom image with all the necessary plugins pre-installed.
  * **Ports:**
      * `8080:8080`: This maps the Jenkins web interface to `http://localhost:8080` on your host machine.
  * **Environment:**
      * `DOCKER_HOST=tcp://docker:2376`: This critical variable tells this Jenkins container *not* to look for a local Docker installation, but to send all Docker commands to the service named `docker` on its network.
      * `CASC_JENKINS_CONFIG`: Points to the Jenkins Configuration as Code (`.yaml`) file, allowing Jenkins to configure itself automatically on startup.
  * **Volumes:**
      * It mounts the `jenkins.yaml` file for configuration.
      * It uses a **named volume** called `jenkins_home` to persist all Jenkins data (jobs, build history, etc.) between restarts.

### 2\. The Docker-in-Docker Service (`docker`)

This service provides an isolated Docker environment for the Jenkins service to use. This is a best practice that prevents the Jenkins controller from needing direct, privileged access to your host machine's Docker daemon.

  * **Image:** It uses the official `docker:dind` (Docker-in-Docker) image.
  * **Privileged Mode:** It runs in `privileged` mode, which is required for a container to run its own Docker daemon inside of it.
  * **Ports:**
      * `2376:2376`: Exposes the internal Docker daemon's API to other containers on the network, which is how the `jenkins` service connects to it.

-----

## How to Start Fresh (Clean Boot)

If you want to completely reset your Jenkins instance—deleting all build history, jobs, and configurations—and start fresh from the state defined in your `jenkins.yaml` file, you need to remove the containers and the named volume that stores the data.

The `-v` flag in the `down` command is the key to removing the `jenkins_home` volume.

### Clean Restart Instructions

Run the following two commands in your terminal from the same directory as your `docker-compose.yml` file:

1.  **Stop and Remove Everything** 🧹

    This command stops the services, removes the containers, and, most importantly, deletes the `jenkins_home` named volume.

    ```bash
    docker-compose down -v
    ```

2.  **Rebuild and Start Fresh** ✨

    This command rebuilds the Jenkins image (if you've changed the `Dockerfile`) and starts the containers with a new, empty `jenkins_home` volume. Jenkins will then run its first-time setup automatically using your `jenkins.yaml` file.

    ```bash
    docker-compose up --build -d
    ```

After these steps, you will have a completely clean Jenkins instance, configured exactly as defined in your code.
