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

# Read the cloudflared enabled value
CLOUDFLARE_ENABLED=$(yq eval '.cloudflared.enabled' config.yaml)
echo "cloudflared enabled: $CLOUDFLARE_ENABLED"


# Read the Datadog enabled value
DATADOG_ENABLED=$(yq eval '.datadog.enabled' config.yaml)
echo "Datadog enabled: $DATADOG_ENABLED"

# Read the Datadog API key
DATADOG_API_KEY=$(yq eval '.["api-key"]' datadog/api-key.yaml)
echo "Datadog API key: $DATADOG_API_KEY"

# Read the Datadog APM enabled value
DATADOG_APM_ENABLED=$(yq eval '.datadog.apm.enabled' config.yaml)
echo "Datadog APM enabled: $DATADOG_APM_ENABLED"


# Check if CLOUDFLARE_ENABLED environment variable is set
if [ -z "$CLOUDFLARE_ENABLED" ]; then
    echo "Error: CLOUDFLARE_ENABLED is not set."
    exit 1
fi

# Check if DATADOG_ENABLED environment variable is set
if [ -z "$DATADOG_ENABLED" ]; then
    echo "Error: DATADOG_ENABLED is not set."
    exit 1
fi

# Read Secret Path from config.yaml
SECRET_PATH=$(yq eval '.secretPath' config.yaml)

# Check if SECRET_PATH environment variable is set
if [ -z "$SECRET_PATH" ]; then
    echo "Error: SECRET_PATH is not set."
    exit 1
fi

# Read Docker password from config.yaml
DOCKER_PASSWORD=$(yq eval '.docker.password' config.yaml)
echo "Docker password: $DOCKER_PASSWORD"

# Check if DOCKER_PASSWORD environment variable is set
if [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: DOCKER_PASSWORD is not set."
    exit 1
fi

# Create the Kubernetes secret for Docker registry
kubectl create secret docker-registry data-service \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=octaidockerhub \
  --docker-password="$DOCKER_PASSWORD" \
  -n default

# Execute commands if cloudflared is enabled
if [ "$CLOUDFLARE_ENABLED" = "true" ]; then
    echo "Setting up cloudflared..."

    # Create configmaps
    kubectl create configmap tunnelcert --from-file=cert.pem=./cloudflare/cert.pem 
    kubectl create configmap credentials --from-file=credentials.json=./cloudflare/credentials.json 

    echo "cloudflared setup completed."
else
    echo "cloudflared is not enabled. Skipping setup."
fi

# Execute commands if Datadog is enabled
if [ "$DATADOG_ENABLED" = "true" ]; then
    echo "Setting up Datadog..."

    # Create secret with Datadog API key
    kubectl create secret generic datadog-secret --from-literal api-key="$DATADOG_API_KEY"

    echo "Datadog setup completed."
else
    echo "Datadog is not enabled. Skipping setup."
fi

# Helm install with Cloudflared, Datadog, and Datadog APM conditionals
helm install \
    --set cloudflared.enabled="$CLOUDFLARE_ENABLED" \
    --set datadog.enabled="$DATADOG_ENABLED" \
    --set datadog.apm.enabled="$DATADOG_APM_ENABLED" \
    --set secretPath="$SECRET_PATH" \
    octai ./octai/octai-0.1.0.tgz
