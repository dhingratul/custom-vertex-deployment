# Custom Vertex AI Model Deployment

This repository provides a template for deploying custom machine learning models to Google Cloud's Vertex AI. It includes scripts for building Docker images, deploying models, and handling GCS (Google Cloud Storage) interactions.

## Prerequisites

- Google Cloud SDK installed and configured
- Docker installed
- Python 3.9 or later
- Access to Google Cloud Project with Vertex AI API enabled
- Service account with necessary permissions

## Project Structure

```
.
├── api/                 # API implementation
├── docker/             # Docker configuration
├── scripts/            # Deployment scripts
├── src/                # Model source code
├── tests/              # Test scripts
├── .env               # Environment configuration
└── test_request.json  # Sample request for testing
```

## Configuration

1. Create a `.env` file with your configuration:

```bash
# Required variables
PROJECT_ID="your-project-id"
REGION="us-central1"
REPOSITORY="your-repository"
IMAGE_NAME="your-image-name"
TAG="latest"
SERVICE_ACCOUNT_NAME="your-sa-name"
```

2. Ensure you have a service account key file (e.g., `key.json`)

## Deployment Process

### 1. Build and Push Docker Image

```bash
./scripts/build_and_deploy.sh
```

This script:
- Builds the Docker image using the Dockerfile in `docker/vertex-api.Dockerfile`
- Tags it appropriately for Vertex AI
- Pushes it to Google Container Registry
- Uploads the model to Vertex AI
- Creates an endpoint (if it doesn't exist)
- Deploys the model to the endpoint
- Configures the necessary environment variables

### 3. Grant GCS Permissions

When deploying to Vertex AI, the model runs under a Vertex AI-managed service account. You need to grant this service account access to your GCS buckets:

```bash
# For input bucket
gsutil iam ch serviceAccount:custom-online-prediction@XXXX.iam.gserviceaccount.com:objectViewer gs://<input_bucket>/

# For output bucket
gsutil iam ch serviceAccount:custom-online-prediction@XXXX.iam.gserviceaccount.com:objectAdmin gs://<output_bucket>/
```

Replace the service account email with the one from your deployment (check error messages if unsure).

## Testing the Deployment

### Using the Python Test Script

```bash
python tests/test_vertex_api.py
```

This script:
- Loads configuration from `.env`
- Constructs a test payload
- Sends it to your endpoint
- Displays the response

Or manually:

```bash
gcloud ai endpoints predict $ENDPOINT_ID \
  --region=us-central1 \
  --json-request=test_request.json
```

### Sample Request Format

```json
{
  "instances": [
    {
      "input_video_path": "gs://<input_bucket>/<input_video_path>",
      "output_gcs_path": "gs://<output_bucket>/<output_video_path>"
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **403 Error on GCS Access**: 
   - Verify that the Vertex AI service account has proper permissions on your GCS buckets
   - Check both input and output bucket permissions

2. **Endpoint Not Found**:
   - Ensure your `.env` file has the correct `ENDPOINT_ID` and `ENDPOINT_URL`
   - Verify the endpoint exists in your project

3. **Docker Build Issues**:
   - Make sure you're using the correct platform (linux/amd64)
   - Check if all required files are present in the build context

## Environment Variables

Key environment variables in `.env`:

- `PROJECT_ID`: Your Google Cloud project ID
- `REGION`: Deployment region (default: us-central1)
- `ENDPOINT_URL`: Full URL for making predictions
- `VERTEX_TEST_MODE`: Enable test mode for development
- `MACHINE_TYPE`: VM type for deployment (default: n1-standard-2)

## Security Best Practices

### Handling Sensitive Information

This repository contains templates for deploying machine learning models to Vertex AI, which requires authentication with Google Cloud. To protect sensitive information:

1. **Service Account Keys**:
   - NEVER commit service account keys (`key.json` or any other credential file) to Git
   - Always add `key.json` and any other key files to `.gitignore`
   - Use a secure method to distribute keys to team members (e.g., a password manager or secure vault)
   - Consider using environment variables or secret management solutions in production

2. **Environment Variables**:
   - Do not commit `.env` files to Git
   - Use `.env.template` as a template for creating your own `.env` file
   - Keep sensitive values (project IDs, URLs) out of version control

3. **Service Account Security**:
   - Follow the principle of least privilege when creating service accounts
   - Regularly rotate service account keys (recommended every 90 days)
   - Delete unused service accounts and revoke unused permissions

4. **Handling Keys in CI/CD**:
   - Use secret management in your CI/CD pipeline
   - Consider using Workload Identity Federation instead of service account keys where possible

5. **Rotating Compromised Credentials**:
   - If you suspect a key has been compromised, rotate it immediately
   - Check the Google Cloud console for unusual activity
   - Review access logs for unexpected access patterns

### First Time Setup

1. Copy the `.env.template` to `.env`:
   ```bash
   cp .env.template .env
   ```

2. Fill in your specific values in the `.env` file

3. Create a service account with the minimal required permissions (see [Prerequisites](#prerequisites))

4. Download the service account key to `key.json` (this file should not be committed to Git)

### Cleaning Up Sensitive Files

If you've accidentally committed sensitive files, use these steps to remove them from Git history:

```bash
# Install BFG Repo-Cleaner if needed
# https://rtyley.github.io/bfg-repo-cleaner/

# Create a backup of your repository
cp -r your-repo your-repo-backup

# Use BFG to remove sensitive files
bfg --delete-files key.json
bfg --delete-files .env

# Clean up and force Git to remove the files from history
cd your-repo
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# Force push changes to remote repository
git push --force
```

⚠️ **Warning**: This rewrites Git history and requires all collaborators to reclone the repository.

## Security Notes

- Never commit your `key.json` file to version control
- Use environment variables for sensitive configuration
- Follow the principle of least privilege when granting permissions
- Regularly rotate service account keys

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request