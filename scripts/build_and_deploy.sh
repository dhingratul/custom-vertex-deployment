#!/bin/bash

# Enable more verbose output
set -x

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
    echo "PROJECT_ID=$PROJECT_ID"
    echo "REPOSITORY=$REPOSITORY"
    echo "IMAGE_NAME=$IMAGE_NAME"
    echo "TAG=$TAG"
    echo "MODEL_NAME=$MODEL_NAME"
    exit 1
fi

# Check if key file path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 path/to/key.json"
    exit 1
fi
KEY_FILE=$1
echo "Using key file: $KEY_FILE"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file not found at $KEY_FILE"
    exit 1
fi

# Verify file contains valid JSON
if ! jq . "$KEY_FILE" > /dev/null 2>&1; then
    echo "Error: Key file is not valid JSON"
    exit 1
fi

# Check if base64 command exists
if ! command -v base64 &> /dev/null; then
    echo "Error: base64 command not found. Please install it."
    exit 1
fi

# Read and base64 encode the key file content
ENCODED_KEY=$(cat "$KEY_FILE" | base64)
if [ -z "$ENCODED_KEY" ]; then
    echo "Error: Failed to read or encode key file."
    exit 1
fi

# Verify gcloud auth
echo "Verifying gcloud authentication..."
gcloud auth print-access-token > /dev/null || {
    echo "Error: Not authenticated with gcloud. Run 'gcloud auth login' first."
    exit 1
}

# Build and push the Docker image
echo "Building and pushing the Docker image..."
docker buildx build --platform=linux/amd64 --push \
  -f docker/vertex-api.Dockerfile \
  -t us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:$TAG \
  .

# Check if the Docker image exists
echo "Verifying Docker image exists..."
DOCKER_IMAGE="us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:$TAG"
if ! gcloud artifacts docker images describe "$DOCKER_IMAGE" > /dev/null 2>&1; then
    echo "Error: Docker image $DOCKER_IMAGE not found. Please run build.sh first."
    exit 1
fi

echo "Deploying the model to Vertex AI..."

# --- Upload the Model ---
echo "Uploading Vertex AI model..."
# Execute command and capture all output (stdout & stderr)
UPLOAD_OUTPUT=$(gcloud ai models upload \
  --region=us-central1 \
  --display-name="$MODEL_NAME" \
  --container-image-uri="$DOCKER_IMAGE" \
  --container-predict-route=/predict \
  --container-health-route=/health \
  --container-env-vars="GCP_SERVICE_ACCOUNT_KEY=$ENCODED_KEY" \
  --format=json)

UPLOAD_STATUS=$?
echo "Upload command exit status: $UPLOAD_STATUS"
echo "Upload output: $UPLOAD_OUTPUT"

# If output is JSON, try to parse the model ID directly
if [[ "$UPLOAD_OUTPUT" == *"\"name\""* ]]; then
    MODEL_ID=$(echo "$UPLOAD_OUTPUT" | jq -r '.name')
else
    # Otherwise try to extract it using grep
    MODEL_ID=$(echo "$UPLOAD_OUTPUT" | grep -Eo 'projects/[^/]+/locations/[^/]+/models/[0-9]+')
fi

# Check status and if MODEL_ID was successfully extracted
if [ $UPLOAD_STATUS -ne 0 ] || [ -z "$MODEL_ID" ]; then
    echo "Error: Failed to upload model."
    echo "Full upload output: $UPLOAD_OUTPUT"
    exit 1
fi
echo "Model uploaded successfully with ID: $MODEL_ID"

# --- Check/Create Endpoint ---
echo "Checking for existing endpoint..."
# Use proper quoting for filter and output format
ENDPOINTS_LIST=$(gcloud ai endpoints list \
  --region=us-central1 \
  --filter="displayName:$MODEL_NAME" \
  --format=json)

# Check if the endpoints list command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to list endpoints"
    echo "Endpoints list output: $ENDPOINTS_LIST"
    exit 1
fi

# Check if any endpoints were returned
if [ "$(echo "$ENDPOINTS_LIST" | jq 'length')" -gt 0 ]; then
    # Get the first endpoint ID
    ENDPOINT_ID=$(echo "$ENDPOINTS_LIST" | jq -r '.[0].name')
    echo "Using existing endpoint: $ENDPOINT_ID"
else
    echo "Creating Vertex AI endpoint..."
    # Create a new endpoint
    CREATE_OUTPUT=$(gcloud ai endpoints create \
      --region=us-central1 \
      --display-name="$MODEL_NAME" \
      --format=json)
    
    CREATE_STATUS=$?
    echo "Endpoint creation status: $CREATE_STATUS"
    echo "Endpoint creation output: $CREATE_OUTPUT"
    
    if [ $CREATE_STATUS -ne 0 ]; then
        echo "Error: Failed to create endpoint."
        echo "Full creation output: $CREATE_OUTPUT"
        # Attempt to clean up the uploaded model
        echo "Attempting to delete uploaded model: $MODEL_ID"
        gcloud ai models delete "$MODEL_ID" --region=us-central1 --quiet
        exit 1
    fi
    
    # Extract endpoint ID from JSON response
    ENDPOINT_ID=$(echo "$CREATE_OUTPUT" | jq -r '.name')
    
    if [ -z "$ENDPOINT_ID" ] || [ "$ENDPOINT_ID" == "null" ]; then
        echo "Error: Failed to extract endpoint ID from response"
        echo "Full creation output: $CREATE_OUTPUT"
        exit 1
    fi
    
    echo "Endpoint created successfully with ID: $ENDPOINT_ID"
fi

# --- Deploy Model to Endpoint ---
echo "Deploying model to endpoint..."
# Use the extracted MODEL_ID and ENDPOINT_ID
DEPLOY_OUTPUT=$(gcloud ai endpoints deploy-model "$ENDPOINT_ID" \
  --region=us-central1 \
  --model="$MODEL_ID" \
  --display-name="$MODEL_NAME" \
  --machine-type=n1-standard-4 \
  --traffic-split=0=100 \
  --format=json)

DEPLOY_STATUS=$?
echo "Model deployment status: $DEPLOY_STATUS"
echo "Model deployment output: $DEPLOY_OUTPUT"

if [ $DEPLOY_STATUS -ne 0 ]; then
    echo "Error: Failed to deploy model to endpoint."
    echo "Full deployment output: $DEPLOY_OUTPUT"
    # Consider cleanup options here if needed
    exit 1
fi

echo "Model deployed successfully to endpoint $ENDPOINT_ID!"
echo "Deployment process completed!"

# Print how to use the endpoint
echo ""
echo "To use this endpoint for predictions, you can use the following command:"
echo "gcloud ai endpoints predict $ENDPOINT_ID --region=us-central1 --json-request=YOUR_REQUEST_FILE.json"
echo ""
echo "For automation, ENDPOINT_ID=$ENDPOINT_ID"