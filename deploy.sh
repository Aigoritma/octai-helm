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

# Check and install yq if not present
check_and_install_yq

check_and_install_helm() {
    # Function to install Helm
    install_helm() {
        echo "Installing Helm..."
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    }
    # Function to upgrade Helm
    upgrade_helm() {
        echo "Upgrading Helm..."
        helm repo update
    }
    # Check if Helm is installed
    if ! command -v helm &> /dev/null
    then
        install_helm
    else
        upgrade_helm
    fi
    # Verify Helm installation
    helm version
}

check_and_install_helm

aws eks update-kubeconfig --name octai-cluster-test

################################################
# NGINX
################################################

# Check if Ingress SSL certificate value are set
SSL_CERTIFICATE=$(yq e '.["ssl-cert"]' config.yaml)
echo "SSL Certificate: $SSL_CERTIFICATE"

# Check if SSL_CERTIFICATE environment variable is set
if [ -z "$SSL_CERTIFICATE" ]; then
    echo "Error: SSL_CERTIFICATE is not set."
    exit 1
fi

# Check if the release already exists in the specified namespace
if helm list -n ingress-nginx --short | grep -q "^ingress-nginx$"; then
    echo "Ingress Nginx release already exists. Upgrading..."
    helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
        -f ./values/nginxValues.yaml \
        -n ingress-nginx --create-namespace \
        --set service.annotations.service.beta.kubernetes.io/aws-load-balancer-ssl-cert="$SSL_CERTIFICATE"
else
    echo "Ingress Nginx release does not exist. Installing..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        -f ./values/nginxValues.yaml \
        -n ingress-nginx --create-namespace \
        --set service.annotations.service.beta.kubernetes.io/aws-load-balancer-ssl-cert="$SSL_CERTIFICATE"
fi

#############################################
# RELOADER
#############################################

# create namespace if it doesn't exist
kubectl get namespace supplementary &> /dev/null || kubectl create namespace supplementary

# Check if the reloader release already exists in the specified namespace
if helm list -n supplementary --short | grep -q "^reloader$"; then
    echo "Reloader release already exists. Upgrading..."

    helm upgrade reloader stakater/reloader -f ./values/stakaterValues.yaml -n supplementary
else
    echo "Reloader release does not exist. Installing..."

    helm repo add stakater https://stakater.github.io/stakater-charts
    helm repo update
    helm install reloader stakater/reloader -f ./values/stakaterValues.yaml -n supplementary # For helm3 add --generate-name flag or set the release name

fi

###############################################
# EXTERNAL-SECRET
###############################################

# Check if the external-secrets release already exists in the specified namespace
if helm list -n supplementary --short | grep -q "^external-secrets$"; then
    echo "External Secrets release already exists. Upgrading..."
    helm upgrade external-secrets external-secrets/kubernetes-external-secrets -f ./values/externalSecretsValues.yaml -n supplementary --version 8.5.3
else
    echo "External Secrets release does not exist. Installing..."
    helm repo add external-secrets https://external-secrets.github.io/kubernetes-external-secrets/
    helm repo update
    helm install external-secrets external-secrets/kubernetes-external-secrets -f ./values/externalSecretsValues.yaml -n supplementary --create-namespace --version 8.5.3
fi

###################################################
# CLOUDFLARED
###################################################

# Read the cloudflared enabled value
CLOUDFLARE_ENABLED=$(yq eval '.cloudflared.enabled' config.yaml)
echo "cloudflared enabled: $CLOUDFLARE_ENABLED"

# Check if CLOUDFLARE_ENABLED environment variable is set
if [ -z "$CLOUDFLARE_ENABLED" ]; then
    echo "Error: CLOUDFLARE_ENABLED is not set."
    exit 1
fi

# Execute commands if cloudflared is enabled
if [ "$CLOUDFLARE_ENABLED" = "true" ]; then
    echo "Setting up cloudflared..."

    # Create configmaps
    kubectl get namespace cloudflared &> /dev/null || kubectl create namespace cloudflared
    kubectl create configmap tunnelcert --from-file=cert.pem=./cloudflare/cert.pem -n cloudflared
    kubectl create configmap credentials --from-file=credentials.json=./cloudflare/credentials.json -n cloudflared

    # Install cloudflared using Helm

    echo "cloudflared setup completed."
else
    echo "cloudflared is not enabled. Skipping setup."
fi

# Check if the cloudflared release already exists in the specified namespace
if [ "$CLOUDFLARE_ENABLED" = "true" ]; then
    echo "Cloudflare is enabled. Proceeding with setup..."

    # Check if the cloudflared release already exists in the specified namespace
    if helm list -n cloudflared --short | grep -q "^cloudflared$"; then
        echo "Cloudflared release already exists. Upgrading..."
        helm upgrade cloudflared k8s-service/k8s-service -f ./values/cloudflaredValues.yaml -n cloudflared
    else
        echo "Cloudflared release does not exist. Installing..."
        helm repo add k8s-service https://helmcharts.gruntwork.io
        helm repo update
        helm install cloudflared k8s-service/k8s-service -f ./values/cloudflaredValues.yaml -n cloudflared --create-namespace
    fi
else
    echo "Cloudflare is not enabled. Skipping setup."
fi

################################################
# DATADOG
################################################

# Read the Datadog enabled value
DATADOG_ENABLED=$(yq eval '.datadog.enabled' config.yaml)
echo "Datadog enabled: $DATADOG_ENABLED"

# Check if DATADOG_ENABLED environment variable is set
if [ -z "$DATADOG_ENABLED" ]; then
    echo "Error: DATADOG_ENABLED is not set."
    exit 1
fi

# Read the Datadog API key
DATADOG_API_KEY=$(yq eval '.["api-key"]' datadog/api-key.yaml)
echo "Datadog API key: $DATADOG_API_KEY"

# Read the Datadog APM enabled value
DATADOG_APM_ENABLED=$(yq eval '.datadog.apm.enabled' config.yaml)
echo "Datadog APM enabled: $DATADOG_APM_ENABLED"

# Check if DATADOG_APM_ENABLED environment variable is set
if [ -z "$DATADOG_APM_ENABLED" ]; then
    echo "Error: DATADOG_APM_ENABLED is not set."
    exit 1
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
##########################################
# HOSTNAME
##########################################

# Read the Hostname value
HOSTNAME=$(yq e '.hostname' config.yaml)
echo "Hostname: $HOSTNAME"

# Check if HOSTNAME environment variable is set
if [ -z "$HOSTNAME" ]; then
    echo "Error: HOSTNAME is not set."
    exit 1
fi
######################################
# DOCKER PAT
######################################

# Read Docker password from config.yaml
DOCKER_PASSWORD=$(yq eval '.docker.password' config.yaml)
echo "Docker password: $DOCKER_PASSWORD"

# Check if DOCKER_PASSWORD environment variable is set
if [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: DOCKER_PASSWORD is not set."
    exit 1
fi

# Create the Kubernetes secret for Docker registry
kubectl create secret docker-registry octai \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=octaidockerhub \
  --docker-password="$DOCKER_PASSWORD" \
  -n default

#####################################
# OCTAI HELM
#####################################

# Add Helm repository for Octai
helm repo add octai https://aigoritma.github.io/octai-helm/

# Update Helm repository
helm repo update

# Helm install with Cloudflared, Datadog, and Datadog APM conditionals
helm install \
    --set cloudflared.enabled="$CLOUDFLARE_ENABLED" \
    --set datadog.enabled="$DATADOG_ENABLED" \
    --set datadog.apm.enabled="$DATADOG_APM_ENABLED" \
    --set ingress.hosts[0].host="$HOSTNAME" \
    --set ingress.hosts[0].paths[0].path=/ \
    --set ingress.hosts[0].paths[0].pathType=Prefix \
    octai octai/octai
