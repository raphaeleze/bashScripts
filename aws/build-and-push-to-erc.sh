#!/bin/bash
# Exit the script as soon as a command fails
set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
DOCKERFILE_PATH="$SCRIPT_DIR/../docker-image/"

# Define variables
IMAGE_TAG="docker-image:latest"  # Change 'latest' to your preferred tag
ECR_REPO_NAME="docker-image-ecr-repo"
AWS_REGION="us-west-2"  # Change this to your AWS region
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Navigate to the Dockerfile directory
cd "$DOCKERFILE_PATH" || exit
pwd

# Build the Docker image
docker build -t $IMAGE_TAG .

# Navigate back to the original directory
cd - || exit
pwd

# Authenticate Docker to the Amazon ECR registry
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag the Docker image for the ECR repository
docker tag $IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Push the Docker image to the ECR repository
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

echo "Image pushed to ECR repository successfully."
