import os
import json
import logging
from google.oauth2 import service_account
from google.cloud import storage

logger = logging.getLogger(__name__)

def init_gcp_auth():
    """
    Initialize GCP authentication using the service account key.
    The key can be provided in two ways:
    1. As a file at /secrets/key.json (for Vertex AI deployment)
    2. As an environment variable GCP_SERVICE_ACCOUNT_KEY (base64 encoded JSON)
    """
    # Check if service account key file exists
    key_file_path = "/secrets/key.json"
    if os.path.exists(key_file_path):
        logger.info(f"Using service account key from file: {key_file_path}")
        # This will be automatically picked up by the GCP client libraries
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = key_file_path
        return True

    # Check if service account key is provided in environment variable
    service_account_key = os.environ.get("GCP_SERVICE_ACCOUNT_KEY")
    if service_account_key:
        try:
            # Decode and parse the service account key JSON
            import base64
            key_json = json.loads(base64.b64decode(service_account_key))

            # Create credentials from the key JSON
            credentials = service_account.Credentials.from_service_account_info(key_json)

            # Test the credentials by listing storage buckets
            storage_client = storage.Client(credentials=credentials)
            logger.info("Successfully authenticated with GCP")
            return True

        except Exception as e:
            logger.error(f"Failed to initialize GCP auth from environment variable: {str(e)}")
            return False

    logger.warning("No GCP service account key found")
    return False
