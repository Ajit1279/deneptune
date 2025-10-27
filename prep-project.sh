#!/bin/bash
# Ensure GCP project is set before running
# Example:
#   gcloud config set project PROJECT_ID

if [[ -z "${GOOGLE_CLOUD_PROJECT}" ]]; then
    echo "❌ Project has not been set! Please run:"
    echo "   gcloud config set project PROJECT_ID"
    echo "(where PROJECT_ID is the desired project)"
    exit 1
else
    echo "✅ Project Name: $GOOGLE_CLOUD_PROJECT"

    PROJECT_ID=$(gcloud config get-value project)
    DATASET="neptune"

    echo "⏳ Enabling required APIs..."
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

    echo "🔹 Retrieving project number..."
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
    echo "Project Number: $PROJECT_NUMBER"

    COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    echo "Default Compute Engine SA: $COMPUTE_SA"

    echo "🔍 Checking if default Compute Engine service account exists..."
    if ! gcloud iam service-accounts describe "$COMPUTE_SA" --project "$PROJECT_ID" >/dev/null 2>&1; then
        echo "⚠️ Default Compute Engine service account not found. Creating one..."
        gcloud iam service-accounts create compute \
          --display-name="Compute Engine default service account"
    else
        echo "✅ Default Compute Engine service account found."
    fi

    echo "👤 Granting your user Service Account Token Creator role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="user:$(gcloud config get-value account)" \
      --role="roles/iam.serviceAccountTokenCreator"

    echo "⏳ Waiting 30 seconds for IAM propagation..."
    sleep 30

    echo "🧪 Testing impersonation..."
    if gcloud auth print-access-token --impersonate-service-account="$COMPUTE_SA" >/dev/null 2>&1; then
        echo "✅ Impersonation successful."
    else
        echo "❌ Impersonation failed. Check your IAM roles or retry after a minute."
        exit 1
    fi

    echo "⚙️ Setting impersonation context..."
    gcloud config set auth/impersonate_service_account "$COMPUTE_SA"

    echo "🔐 Granting BigQuery Data Editor role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$COMPUTE_SA" \
      --role="roles/bigquery.dataEditor"

    echo "🔐 Granting Pub/Sub Subscriber role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$COMPUTE_SA" \
      --role="roles/pubsub.subscriber"

    echo "🪣 Creating Cloud Storage bucket..."
    gcloud storage buckets create "gs://${GOOGLE_CLOUD_PROJECT}-bucket" --soft-delete-duration=0

    echo "🗂️ Creating BigQuery dataset and tables..."
    bq mk --location=US --dataset "$DATASET" 2>/dev/null || echo "Dataset already exists."

    bq mk --schema message:STRING -t "$DATASET.rawmessages" 2>/dev/null || echo "Table rawmessages exists."
    bq mk --table "$DATASET.parsedmessages" \
      id:STRING,ipaddress:STRING,action:STRING,accountnumber:STRING,actionid:INTEGER,name:STRING,actionby:STRING 2>/dev/null || echo "Table parsedmessages exists."

    echo "📡 Setting up Pub/Sub topics and subscriptions..."
    gcloud pubsub topics create neptune-activities 2>/dev/null || echo "Topic already exists."
    gcloud pubsub subscriptions create neptune-activities-test --topic neptune-activities 2>/dev/null || echo "Subscription exists."

    echo "🔗 Creating cross-project subscription to Moonbank..."
    gcloud pubsub subscriptions create neptune-activities \
      --topic "projects/moonbank-neptune/topics/activities" \
      --push-endpoint="https://pubsub.googleapis.com/v1/projects/${GOOGLE_CLOUD_PROJECT}/topics/neptune-activities:publish" 2>/dev/null || echo "Cross-project subscription exists."

    echo "✅ Pre-project setup completed successfully."
fi