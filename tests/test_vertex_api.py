#!/usr/bin/env python
"""
Test script for Vertex AI endpoint.
Sends a request in Vertex AI format to the deployed endpoint.
"""

import argparse
import json
import subprocess
import os
import logging
import time
import requests
from dotenv import load_dotenv

load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_auth_token():
    """Get GCP authentication token using gcloud"""
    try:
        result = subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to get auth token: {e}")
        raise


def main():
    # Construct the request payload in Vertex AI format
    # Each dictionary in the 'instances' list represents a single prediction request
    payload = {
        "instances": [
            {
                "input_video_path": os.getenv("INPUT_GCS_PATH"),
                "output_gcs_path": os.getenv("OUTPUT_GCS_PATH")
            }
            # Add more instances here to test batch prediction if needed
        ]
    }
    logger.info(f"Payload: {json.dumps(payload, indent=2)}")

    # Get auth token
    token = get_auth_token()

    # Construct the endpoint URL
    endpoint_url = os.getenv("ENDPOINT_URL")
    if not endpoint_url:
        logger.error("ENDPOINT_URL environment variable not set. Please set it (e.g., in .env file) or run deploy script.")
        return # Exit if URL is missing

    logger.info(f"Sending request to: {endpoint_url}")

    # Send the request
    try:
        response = requests.post(
            endpoint_url,
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
        )

        logger.info(f"Status code: {response.status_code}")
        if response.status_code == 200:
            logger.info("Success! Response:")
            logger.info(json.dumps(response.json(), indent=2))
        else:
            logger.error(f"Error: {response.text}")

    except Exception as e:
        logger.error(f"Request failed: {str(e)}")


if __name__ == "__main__":
    main()
