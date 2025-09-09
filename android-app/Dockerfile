# Start with a slim Java 17 base image
FROM openjdk:17-slim-bullseye

# Set environment variables for Android SDK paths and versions
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools"

# Version of the Android command-line tools to download
ENV ANDROID_SDK_TOOLS_REV="13114758"

# Versions for the build tools and platform SDK
ENV ANDROID_BUILD_TOOLS_VERSION="36.0.0"
ENV ANDROID_SDK_VERSION="36"

# Install system packages and create the Android SDK directory
RUN apt-get update && \
    apt-get -y install wget unzip socat xsltproc python3 zip sshpass && \
    mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools

# Download and set up the Android command-line tools in the correct location
RUN wget --quiet --output-document=${ANDROID_SDK_ROOT}/android-sdk.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_REV}_latest.zip && \
    unzip -qq ${ANDROID_SDK_ROOT}/android-sdk.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm ${ANDROID_SDK_ROOT}/android-sdk.zip

# Use sdkmanager to accept licenses and update
RUN yes | sdkmanager --licenses > /dev/null && \
    yes | sdkmanager --update > /dev/null
