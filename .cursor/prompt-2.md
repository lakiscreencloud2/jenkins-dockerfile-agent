# Mission Objective

Your mission is to adapt our existing Jenkins pipeline to build a real Android application. You will modify the inline pipeline script in `jenkins.yaml` to use a custom Android `Dockerfile`, execute a Gradle build, and archive the resulting APK artifact. You will work iteratively, debugging any issues until the pipeline succeeds.

-----

# Context & Current State

## 1\. The Goal

We are moving from a simple "hello world" test to a real-world use case: building an Android app. The core requirements for the new pipeline are:

  * Use the `Dockerfile` located inside the `android-app/` directory as the build agent.
  * Execute a standard Gradle build command (`./gradlew clean assembleDebug`).
  * Archive the compiled APK file(s) for later use.

## 2\. System Changes from Last Known Good State

The environment has changed significantly. You must account for the following:

  * The `build/` directory has been **removed**.
  * A new `android-app/` directory has been added. It contains a complete Android Studio project.
  * The `Dockerfile` defining the build environment is now located at `android-app/Dockerfile`.

## 3\. Current File System

This is the new project structure. Your primary focus will be modifying the `script` section inside `jenkins.yaml`.

```
.
├── docker-compose.yml   # Unchanged, assumed working
├── jenkins.yaml         # 👈 Your primary target for modification
└── android-app/
    ├── gradlew          # The Gradle wrapper script
    ├── app/
    │   └── build.gradle
    ├── Dockerfile       # The new Dockerfile for the build environment
    └── ... (other Android project files)
```

# Your Task: Iterative Android Build Workflow

Follow these steps to update and validate the new pipeline. Address one step at a time, testing your changes before proceeding.

### **Step 1: Update the Pipeline in `jenkins.yaml`**

Modify the inline Groovy script within `jenkins.yaml` to perform the Android build. This involves several key changes:

1.  **Update the Agent:** The `agent` directive must now point to the new Dockerfile location. Change `dir 'build'` to `dir 'android-app'`.
2.  **Create a 'Build' Stage:** Replace the old stages with a new `stage('Build')`.
3.  **Add Build Steps inside a `dir` block:** The Gradle commands must be run from within the `android-app` directory. Use a `dir('android-app')` block to wrap the build steps.
      * **Grant Permissions:** The `gradlew` script checked out from source control often lacks execute permissions. Your first command inside the `dir` block **must be** `sh 'chmod +x gradlew'`.
      * **Run Gradle:** The second command is the build itself: `sh './gradlew clean assembleDebug'`.
4.  **Create an 'Archive' Stage:** After the build stage, add a `stage('Archive APK')`.
      * **Archive the Artifacts:** Inside this stage, use the `archiveArtifacts` step to save the APK. The path will be inside the `android-app` directory. The command should be: `archiveArtifacts artifacts: 'android-app/app/build/outputs/apk/debug/*.apk', followSymlinks: false`.

### **Step 2: Trigger, Analyze, and Debug**

This process is the same as before, but the potential errors are different.

1.  **Start Jenkins:** Run `docker-compose up -d --build`.
2.  **Request API Key:** When you are ready to test the pipeline, ask me: **"I have updated the pipeline for the Android build. Please provide the admin API key."**
3.  **Trigger and Analyze:** Use the `curl` commands from our previous session to trigger the build and fetch the console logs.
4.  **Iterate and Fix:** The Android build may fail for several reasons. Analyze the console output carefully for common issues:
      * **Permission Denied:** You forgot the `chmod +x gradlew` step.
      * **Gradle Errors:** Issues with dependencies, build tools versions, or the Gradle daemon failing inside the container.
      * **Artifacts Not Found:** The path in the `archiveArtifacts` step is incorrect, or the build failed to produce an APK.
      * **Container Errors:** Problems with the `android-app/Dockerfile` itself (e.g., missing tools).

Modify the pipeline in `jenkins.yaml` to fix any errors, restart Jenkins, and re-trigger the build until it succeeds.

-----

# Final Deliverables

Upon successful completion of the Android build and artifact archiving, provide:
- A brief but clear summary of the changes made to the pipeline script and the reason for each change (e.g., "Updated agent path," "Added chmod for gradlew," etc.).
