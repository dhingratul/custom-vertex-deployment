# Use a lightweight Python base image with amd64 platform
# Use a lightweight Python base image
ARG PLATFORM=linux/amd64
FROM --platform=$PLATFORM python:3.9-slim

# Set working directory
WORKDIR /app

# Install OS dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy necessary files
COPY ./api ./api
COPY ./src ./src
COPY ./requirements.txt ./requirements.txt

# Set executable permissions
RUN chmod +x /app/src/model.py

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Verify we're running on the correct architecture
RUN echo "Verifying architecture:" && arch && \
    if [ "$(arch)" != "x86_64" ]; then echo "WARNING: Not running on x86_64 architecture"; fi

# Expose the port for FastAPI
EXPOSE 8080

# Set environment variables for Vertex AI
ENV AIP_PREDICT_ROUTE="/predict"
ENV AIP_HEALTH_ROUTE="/health"
ENV AIP_HTTP_PORT="8080"
ENV PORT="8080"
# Disable test mode for real processing
ENV VERTEX_TEST_MODE="false"

# Use exec form of CMD to avoid /bin/sh interpreter issues
CMD ["uvicorn", "api.api:app", "--host", "0.0.0.0", "--port", "8080"]
