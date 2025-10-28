#!/bin/bash
set -e

# ==========================================
# Configuration
# ==========================================
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
TOPIC="neptune-activities"
BQ_DATASET="neptune"
FUNCTION_NAME="neptuneProcessor"
SA_NAME="netunesa"
ENTRY_POINT="process_pubsub"
RUNTIME="python312"

echo "=============================================="
echo "Starting Cloud Function Deployment (Local Project)"
echo "----------------------------------------------"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Topic: ${TOPIC}"
echo "=============================================="

# ==========================================
# Step 1: Create Service Account (if missing)
# ==========================================
echo "Creating service account ${SA_NAME} in ${PROJECT_ID}..."
if ! gcloud iam service-accounts describe ${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID} &>/dev/null; then
  gcloud iam service-accounts create ${SA_NAME} \
    --display-name "Neptune Data Service Account" \
    --project=${PROJECT_ID}
else
  echo "Service account already exists."
fi

# ==========================================
# Step 2: Create BigQuery Dataset (if missing)
# ==========================================
echo "Ensuring BigQuery dataset ${BQ_DATASET} exists..."
if ! bq --project_id=${PROJECT_ID} ls ${BQ_DATASET} &>/dev/null; then
  bq --project_id=${PROJECT_ID} mk --dataset ${PROJECT_ID}:${BQ_DATASET}
else
  echo "Dataset already exists."
fi

# ==========================================
# Step 3: Grant BigQuery Data Editor role to SA
# ==========================================
echo "Granting BigQuery Data Editor role to ${SA_NAME}..."
if ! gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor" --quiet; then
  echo "Could not update IAM policy (likely due to lab restrictions). Continuing..."
fi

# ==========================================
# Step 4: Prepare Cloud Function Source Code
# ==========================================
echo "Preparing Cloud Function source..."
mkdir -p cf-src
cat > cf-src/main.py <<'EOF'
import base64
import json
from google.cloud import bigquery

def process_pubsub(event, context):
    """Triggered from a message on a Pub/Sub topic."""
    try:
        if 'data' in event:
            message = base64.b64decode(event['data']).decode('utf-8')
            record = json.loads(message)
        else:
            record = {"error": "no data"}
        
        client = bigquery.Client()
        table_id = f"{client.project}.neptune.rawmessages"
        errors = client.insert_rows_json(table_id, [record])
        if errors:
            print(f"BigQuery insertion errors: {errors}")
        else:
            print(f"Inserted record: {record}")
    except Exception as e:
        print(f"Error processing message: {e}")
EOF

cat > cf-src/requirements.txt <<'EOF'
google-cloud-bigquery
EOF

# ==========================================
# Step 5: Ensure Pub/Sub Topic Exists
# ==========================================
echo "Ensuring Pub/Sub topic '${TOPIC}' exists..."
if ! gcloud pubsub topics describe ${TOPIC} --project=${PROJECT_ID} &>/dev/null; then
  gcloud pubsub topics create ${TOPIC} --project=${PROJECT_ID}
  echo "Topic created."
else
  echo "Topic already exists."
fi

# ==========================================
# Step 6: Deploy Cloud Function (within same project)
# ==========================================
echo "Deploying Cloud Function to ${PROJECT_ID}..."
echo "   (Using max-instances=2 to control scaling)"

gcloud functions deploy ${FUNCTION_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --runtime=${RUNTIME} \
  --trigger-topic=${TOPIC} \
  --entry-point=${ENTRY_POINT} \
  --service-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --source=cf-src \
  --set-env-vars="BQ_PROJECT=${PROJECT_ID},BQ_DATASET=${BQ_DATASET}" \
  --max-instances=2 \
  --memory=256MB \
  --quiet

echo "Cloud Function deployed successfully!"
echo "----------------------------------------------"
echo "Function: ${FUNCTION_NAME}"
echo "Project: ${PROJECT_ID}"
echo "Dataset: ${PROJECT_ID}.${BQ_DATASET}"
echo "Topic: ${PROJECT_ID}.${TOPIC}"
echo "Max Instances: 2"
echo "=============================================="
