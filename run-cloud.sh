#!/bin/bash

# ------------------------------
# Environment variables
# ------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
TOPIC_NAME="neptune-activities"
FUNCTION_NAME="pubsub_to_bigquery"
BUCKET_NAME="${PROJECT_ID}-bucket"
FUNCTION_DIR="neptune-function"

# ------------------------------
# Check project is set
# ------------------------------
if [[ -z "$PROJECT_ID" ]]; then
    echo "GCP Project is not set! Run: gcloud config set project PROJECT_ID"
    exit 1
fi

echo "Using GCP Project: $PROJECT_ID"

# ------------------------------
# Install dependencies
# ------------------------------
sudo pip3 install --upgrade -r requirements.txt

# ------------------------------
# Prepare clean function directory
# ------------------------------
rm -rf $FUNCTION_DIR
mkdir $FUNCTION_DIR
cp main.py requirements.txt $FUNCTION_DIR/

# ------------------------------
# Enable required APIs
# ------------------------------
gcloud services enable \
    cloudfunctions.googleapis.com \
    pubsub.googleapis.com \
    bigquery.googleapis.com \
    storage.googleapis.com \
    dataflow.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    eventarc.googleapis.com \
    artifactregistry.googleapis.com

# ------------------------------
# Deploy Cloud Function
# ------------------------------
gcloud functions deploy $FUNCTION_NAME \
    --region=$REGION \
    --runtime=python312 \
    --entry-point=pubsub_to_bigquery \
    --trigger-topic=$TOPIC_NAME \
    --source=$FUNCTION_DIR \
    --project=$PROJECT_ID \
    --timeout=120s \
    --memory=256MB \
    --gen2

# ------------------------------
# Verify deployment
# ------------------------------
echo "Cloud Function deployment status:"
gcloud functions describe $FUNCTION_NAME --region=$REGION
