#!/bin/bash
set -e

# ------------------------------
#  Environment Variables
# ------------------------------
PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project)}
REGION="us-central1"
TOPIC_NAME="neptune-activities"
FUNCTION_DIR="neptune-function"   # directory containing main.py and requirements.txt
FUNCTION_NAME="pubsub_to_bigquery"

echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Topic: $TOPIC_NAME"
echo "Function directory: $FUNCTION_DIR"

# ------------------------------
# 1️ Install dependencies locally (optional)
# ------------------------------
echo "Installing Python dependencies..."
sudo pip3 install -r $FUNCTION_DIR/requirements.txt

# ------------------------------
# 2️ Run local Apache Beam pipeline (optional)
# ------------------------------
echo "Launching streaming pipeline (Beam/Dataflow)..."
python3 $FUNCTION_DIR/main.py \
  --project=$PROJECT_ID \
  --region=$REGION \
  --input_topic=projects/$PROJECT_ID/topics/$TOPIC_NAME \
  --bucket=$PROJECT_ID-bucket

# ------------------------------
# 3️ Deploy 1st gen Cloud Function
# ------------------------------
echo "Deploying Cloud Function (1st gen)..."
gcloud functions deploy $FUNCTION_NAME \
  --project=$PROJECT_ID \
  --region=$REGION \
  --runtime=python312 \
  --entry-point=$FUNCTION_NAME \
  --trigger-topic=$TOPIC_NAME \
  --source=$FUNCTION_DIR \
  --timeout=120s \
  --memory=256MB \
  --quiet \
  --no-gen2

echo " Cloud Function deployed successfully!"

# ------------------------------
# 4️ Verify Cloud Function
# ------------------------------
echo "Verifying Cloud Function..."
gcloud functions describe $FUNCTION_NAME --region=$REGION
