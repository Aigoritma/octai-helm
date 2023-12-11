#Create a script that will deploy the helm chart to the cluster.

#!/bin/bash

set -x # Enable debugging
set -e # Stop script on error

# Function to check if yq is installed and install it if not
check_and_install_yq() {
    if command -v yq &> /dev/null; then
        echo "yq is already installed."
    else
        echo "yq not found. Attempting to install..."
        # Install yq depending on the operating system

        if [ "$(uname)" == "Linux" ]; then
            # Update server
            sudo apt-get update
            # Install yq for Linux
            sudo wget -O /usr/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && sudo chmod a+x /usr/bin/yq
        elif [ "$(uname)" == "Darwin" ]; then
            # Install yq for MacOS
            brew install yq
        else
            echo "Failed to resolve OS name or unsupported OS."
            exit 1
        fi

        # Check if yq was installed successfully
        if command -v yq &> /dev/null; then
            echo "yq installed successfully."
        else
            echo "Failed to install yq. Please install it manually."
            exit 1
        fi
    fi
}

# Check and install jq if not present
check_and_install_yq

# Read Docker password from config.yaml
DOCKER_PASSWORD=$(yq eval '.docker.password' config.yaml)
echo "Docker password: $DOCKER_PASSWORD"

# Check if DOCKER_PASSWORD environment variable is set
if [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: DOCKER_PASSWORD is not set."
    exit 1
fi

# Create the Kubernetes secret for Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=octaidockerhub \
  --docker-password="$DOCKER_PASSWORD" \
  --docker-email=devops@octai.com \
  -n default



