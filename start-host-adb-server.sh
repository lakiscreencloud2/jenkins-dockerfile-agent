#!/bin/bash
# This script downloads the latest Android platform-tools and starts the ADB server
# configured to listen on all network interfaces, making it accessible to the Jenkins Docker container.

set -e # Exit immediately if a command exits with a non-zero status.

PLATFORM_TOOLS_DIR="android-platform-tools"
PLATFORM_TOOLS_ZIP="${PLATFORM_TOOLS_DIR}/platform-tools.zip"
ADB_PATH="${PLATFORM_TOOLS_DIR}/platform-tools/adb"

# Check if the ADB executable already exists.
if [ ! -f "$ADB_PATH" ]; then
  echo "Android platform-tools not found."
  echo "Downloading the latest version..."

  # Ensure the target directory exists.
  mkdir -p "$PLATFORM_TOOLS_DIR"

  # Download the platform-tools zip file.
  wget -q https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O "$PLATFORM_TOOLS_ZIP"

  # Unzip the contents and clean up.
  unzip -q "$PLATFORM_TOOLS_ZIP" -d "$PLATFORM_TOOLS_DIR"
  rm "$PLATFORM_TOOLS_ZIP"

  echo "Download and extraction complete."
else
  echo "Android platform-tools already found in ./${PLATFORM_TOOLS_DIR}/"
fi

echo "---"

# Ensure any previously running ADB server is stopped.
echo "Killing any existing ADB server to prevent conflicts..."
"$ADB_PATH" kill-server || true # Use '|| true' to ignore errors if the server isn't running.

# Start the ADB server, listening on all network interfaces on port 5037.
echo "Starting ADB server to listen on all network interfaces (0.0.0.0:5037)..."
"$ADB_PATH" -a -P 5037 server nodaemon &

# Give the server a moment to initialize.
sleep 2

echo "ADB server started successfully."
echo "You can check for connected devices by running: ./${ADB_PATH} devices"
