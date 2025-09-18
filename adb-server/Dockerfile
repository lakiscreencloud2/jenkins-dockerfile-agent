# Use a modern, glibc-based image.
FROM debian:bullseye-slim

# Define the location for the Android SDK
ENV ANDROID_SDK_ROOT "/opt/android-sdk"
ENV PATH "$PATH:${ANDROID_SDK_ROOT}/platform-tools"

# Install dependencies, download platform-tools directly, and clean up.
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip tini ca-certificates && \
    # Download and install platform-tools from the direct link
    wget --quiet --output-document=/tmp/platform-tools.zip "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" && \
    mkdir -p ${ANDROID_SDK_ROOT} && \
    unzip -q /tmp/platform-tools.zip -d ${ANDROID_SDK_ROOT} && \
    # --- Cleanup ---
    rm /tmp/platform-tools.zip && \
    apt-get purge -y wget unzip && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Use tini as the init system for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]

# Connect to the host's ADB server and keep container running
CMD ["sh", "-c", "export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 && adb devices && tail -f /dev/null"]
