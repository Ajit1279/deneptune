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

rm -rf $FUNCTION_DIR
mkdir $FUNCTION_DIR
cp main.py requirements.txt $FUNCTION_DIR/

# ------------------------------
# 1️ Install dependencies locally (optional)
# ------------------------------
echo "Installing Python dependencies..."
sudo pip3 install -r $FUNCTION_DIR/requirements.txt

# ------------------------------
# 2 Deploy 1st gen Cloud Function
# ------------------------------
echo "Deploying Cloud Function (1st gen)..."

gcloud functions deploy $FUNCTION_NAME \
  --project=moonbank-neptune \
  --region=$REGION \
  --runtime=python312 \
  --entry-point=$FUNCTION_NAME \
  --trigger-topic=$TOPIC_NAME \
  --service-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  --set-env-vars=PROJECT_ID=$PROJECT_ID,DATASET=neptune \
  --source=$FUNCTION_DIR \
  --timeout=120s \
  --memory=256MB \
  --quiet

echo " Cloud Function deployed successfully!"

# ------------------------------
# 3 Verify Cloud Function
# ------------------------------
echo "Verifying Cloud Function..."
gcloud functions describe $FUNCTION_NAME --region=$REGION --format="value(serviceAccountEmail)"
