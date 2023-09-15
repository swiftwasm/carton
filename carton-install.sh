#!/bin/bash

# Define the destination directory
DEST="/usr/local/bin/carton"

# Function to clean up files
cleanup() {
  # Clean up: Remove unnecessary files and the cloned repository
  cd ..
  rm -rf carton
}

# Check if the 'swift' command is available
if ! command -v swift &> /dev/null; then
  echo "Swift is not installed. Installing Swift..."
  
  # Install Swift using swiftly-install.sh
  curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash
  swiftly install latest

  # Check if Swift installation was successful
  if ! command -v swift &> /dev/null; then
    echo "Failed to install Swift. Please check the installation and try again."
    cleanup
    exit 1
  fi
fi

# Clone the Carton repository
git clone https://github.com/swiftwasm/carton.git
cd carton

# Find the latest release tag
latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1))

# Checkout the latest release tag
git checkout $latest_tag

# Install dependencies
./install_ubuntu_deps.sh

# Build Carton
swift build -c release

# Check if the build was successful
if [ $? -eq 0 ]; then
  # Remove the old Carton binary if it exists
  if [ -f $DEST ]; then
    sudo rm $DEST
  fi

  # Move the binary to the destination
  sudo mv .build/release/carton $DEST

  # Set the correct permissions
  sudo chmod 755 $DEST

  echo "Carton has been successfully built and updated to the newest release ($latest_tag) at $DEST."

else
  echo "Carton build failed. Please check the dependencies and try again."
fi

# Clean up in both success and failure cases
cleanup