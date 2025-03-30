import os
import logging
from google.cloud import storage

logger = logging.getLogger(__name__)


def parse_gcs_path(gcs_path: str) -> tuple:
    """Parse a GCS path into bucket name and prefix"""
    if not gcs_path.startswith("gs://"):
        raise ValueError("GCS path must start with gs://")

    bucket_name = gcs_path.split("/")[2]
    prefix = "/".join(gcs_path.split("/")[3:])
    return bucket_name, prefix


def download_from_gcs(gcs_path: str, local_path: str) -> str:
    """Download data from GCS to local path, or use local path directly if not a GCS path"""
    try:
        # Handle GCS path
        client = storage.Client()
        # Parse bucket and blob path
        bucket_name, prefix = parse_gcs_path(gcs_path)

        bucket = client.bucket(bucket_name)
        blob = bucket.blob(prefix)

        # Create local directories if needed
        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        # Download the file
        blob.download_to_filename(local_path)
        logger.info(f"Downloaded {gcs_path} to {local_path}")

        return local_path

    except Exception as e:
        logger.error(f"Error downloading from GCS: {str(e)}")
        raise


def upload_to_gcs(local_path: str, gcs_path: str) -> None:
    """Upload data from local path to GCS, or use local path if not a GCS path"""
    try:
        # If the path is not a GCS path, assume it's a local path
        if not gcs_path.startswith("gs://"):
            logger.info(f"Using local path for output: {gcs_path}")
            return

        # Handle GCS path
        client = storage.Client()
        # Parse bucket and blob path
        bucket_name, prefix = parse_gcs_path(gcs_path)

        bucket = client.bucket(bucket_name)

        # Walk through the local directory and upload files
        for root, _, files in os.walk(local_path):
            for file in files:
                local_file_path = os.path.join(root, file)
                # Get the relative path from the local_path
                rel_path = os.path.relpath(local_file_path, local_path)
                # Construct the GCS path
                gcs_file_path = f"{prefix}/{rel_path}" if prefix else rel_path

                blob = bucket.blob(gcs_file_path)
                blob.upload_from_filename(local_file_path)
                logger.info(
                    f"Uploaded {local_file_path} to gs://{bucket_name}/{gcs_file_path}"
                )

    except Exception as e:
        logger.error(f"Error uploading to GCS: {str(e)}")
        raise
