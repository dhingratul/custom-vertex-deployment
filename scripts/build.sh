#!/bin/bash

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    source .env
else
    echo "No .env file found. Please create one with the required variables."
    exit 1
fi

# Check if required variables are set
if [ -z "$PROJECT_ID" ] || [ -z "$REPOSITORY" ] || [ -z "$IMAGE_NAME" ] || [ -z "$TAG" ] || [ -z "$MODEL_NAME" ]; then
    echo "Error: One or more required environment variables are not set in .env."
    exit 1
fi


# Build and push the Docker image
echo "Building and pushing the Docker image..."
docker buildx build --platform=linux/amd64 --push \
  -f docker/vertex-api.Dockerfile \
  -t us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:$TAG \
  .
