#!/bin/bash

if [[ -z "${GOOGLE_CLOUD_PROJECT}" ]]; then
    echo "Project has not been set! Please run:"
    echo "   gcloud config set project PROJECT_ID"
    exit 1
else
    echo "Project Name: $GOOGLE_CLOUD_PROJECT"

    PROJECT_ID=$(gcloud config get-value project)
    DATASET="neptune"

    echo "Enabling required APIs..."
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

    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
    COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    echo "🔹 Using default Compute Engine service account: $COMPUTE_SA"

    echo "Creating Cloud Storage bucket..."
    gcloud storage buckets create "gs://${GOOGLE_CLOUD_PROJECT}-bucket" --soft-delete-duration=0 2>/dev/null || echo "Bucket already exists."

    echo "Creating BigQuery dataset and tables..."
    bq mk --location=US --dataset "$DATASET" 2>/dev/null || echo "Dataset exists."
    bq mk --schema message:STRING -t "$DATASET.rawmessages" 2>/dev/null || echo "rawmessages exists."
    bq mk --table "$DATASET.parsedmessages" \
      id:STRING,ipaddress:STRING,action:STRING,accountnumber:STRING,actionid:INTEGER,name:STRING,actionby:STRING 2>/dev/null || echo "parsedmessages exists."

    echo "Creating Pub/Sub topics and subscriptions..."
    gcloud pubsub topics create neptune-activities 2>/dev/null || echo "Topic exists."
    gcloud pubsub subscriptions create neptune-activities-test --topic neptune-activities 2>/dev/null || echo "Subscription exists."

    echo "Linking to Moonbank topic..."
    gcloud pubsub subscriptions create neptune-activities \
      --topic projects/moonbank-neptune/topics/activities \
      --push-endpoint="https://pubsub.googleapis.com/v1/projects/${GOOGLE_CLOUD_PROJECT}/topics/neptune-activities:publish" 2>/dev/null || echo "Cross-project subscription exists."

    echo "Pre-project setup completed successfully."
    echo "Use the default Compute SA in your Cloud Function deploy step:"
    echo "   gcloud functions deploy FUNCTION_NAME \\"
    echo "     --service-account=$COMPUTE_SA ..."
fi
