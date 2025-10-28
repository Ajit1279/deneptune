#!/bin/bash
set -e

# ------------------------------
#  Environment Variables
# ------------------------------
LAB_PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project)}
TARGET_PROJECT_ID="moonbank-neptune"
REGION="us-central1"
TOPIC_NAME="neptune-activities"
FUNCTION_DIR="neptune-function"
FUNCTION_NAME="pubsub_to_bigquery"

# Get lab project number and default compute SA
LAB_PROJECT_NUMBER=$(gcloud projects describe $LAB_PROJECT_ID --format="value(projectNumber)")
DEFAULT_SA="${LAB_PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Lab Project: $LAB_PROJECT_ID"
echo "Target Project: $TARGET_PROJECT_ID"
echo "Region: $REGION"
echo "Topic: $TOPIC_NAME"
echo "Using Service Account: $DEFAULT_SA"

# ------------------------------
# 1 Prepare function source
# ------------------------------
rm -rf $FUNCTION_DIR
mkdir $FUNCTION_DIR
cp main.py requirements.txt $FUNCTION_DIR/

# ------------------------------
# 2 Install dependencies locally (optional)
# ------------------------------
echo "Installing Python dependencies..."
sudo pip3 install -r $FUNCTION_DIR/requirements.txt

# ------------------------------
# 3 Deploy Cloud Function (in moonbank-neptune)
# ------------------------------
echo "Deploying Cloud Function to $TARGET_PROJECT_ID ..."

gcloud functions deploy $FUNCTION_NAME \
  --project=$TARGET_PROJECT_ID \
  --region=$REGION \
  --runtime=python312 \
  --entry-point=$FUNCTION_NAME \
  --trigger-topic=$TOPIC_NAME \
  --service-account=$DEFAULT_SA \
  --set-env-vars=PROJECT_ID=$TARGET_PROJECT_ID,DATASET=neptune \
  --source=$FUNCTION_DIR \
  --timeout=120s \
  --memory=256MB \
  --quiet \
  --impersonate-service-account=$DEFAULT_SA

echo "✅ Cloud Function deployed successfully in $TARGET_PROJECT_ID!"

# ------------------------------
# 4 Verify Cloud Function
# ------------------------------
echo "Verifying Cloud Function service account..."
gcloud functions describe $FUNCTION_NAME \
  --region=$REGION \
  --project=$TARGET_PROJECT_ID \
  --format="value(serviceAccountEmail)"
