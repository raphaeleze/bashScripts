#!/bin/bash
# Exit the script as soon as a command fails
set -e

# Connect to the EKS cluster
EKS_CLUSTER_NAME=""  # Change this to your EKS cluster name
REGION="us-west-2"   # Change this to your aws region
aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${REGION} || { echo "Failed to connect to EKS cluster"; exit 1; }

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)" || { echo "Failed to get script directory"; exit 1; }
echo "Script is running from: $SCRIPT_DIR"

# Construct the path to values.yaml relative to the script location
VALUES_PATH="$SCRIPT_DIR/../values.yaml"

# Set variables
NAMESPACE_SYSTEMS="arc-systems"
NAMESPACE_RUNNERS="arc-runners"
CHART_URL="ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
RUNNER_CHART_URL="ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
GITHUB_CONFIG_URL="https://github.com/your-org"

# Retrieve secrets from AWS Secrets Manager
SECRET_NAME="GITHUB-APP-SECRET"
SECRET_VALUES=$(aws secretsmanager get-secret-value --secret-id ${SECRET_NAME} --query SecretString --output text) || { echo "Failed to retrieve secrets"; exit 1; }
GITHUB_APP_ID=$(echo $SECRET_VALUES | jq -r .GITHUB_APP_ID)
GITHUB_APP_INSTALLATION_ID=$(echo $SECRET_VALUES | jq -r .GITHUB_APP_INSTALLATION_ID)

# Create Kubernetes namespaces
kubectl create namespace ${NAMESPACE_SYSTEMS} || echo "Namespace ${NAMESPACE_SYSTEMS} already exists"
kubectl create namespace ${NAMESPACE_RUNNERS} || echo "Namespace ${NAMESPACE_RUNNERS} already exists"

# Create the Kubernetes secret
kubectl create secret generic pre-defined-secret \
  --namespace=arc-runners \
  --from-literal=github_app_id=$GITHUB_APP_ID \
  --from-literal=github_app_installation_id=$GITHUB_APP_INSTALLATION_ID \
  --from-file=github_app_private_key="YOUR-PRIVATE-KEY.PEM" || { echo "Failed to create Kubernetes secret"; exit 1; }

# Deploy Helm chart for arc systems
helm upgrade --install arc oci://${CHART_URL} --namespace ${NAMESPACE_SYSTEMS} || { echo "Failed to deploy Helm chart for arc systems"; exit 1; }

# Deploy Helm chart for arc runners
helm upgrade --install arc-runner-set oci://${RUNNER_CHART_URL} --namespace ${NAMESPACE_RUNNERS} \
  --set githubConfigUrl=${GITHUB_CONFIG_URL} \
  --set githubConfigSecret="pre-defined-secret" \
  -f "$VALUES_PATH" || { echo "Failed to deploy Helm chart for arc runners"; exit 1; }