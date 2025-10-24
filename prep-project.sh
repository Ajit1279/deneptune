#! /bin/bash
# MAKE SURE GCP PROJECT IS SET
# gcloud config set project PROJECT_ID
if [[ -z "${GOOGLE_CLOUD_PROJECT}" ]]; then
    echo "Project has not been set! Please run:"
    echo "   gcloud config set project PROJECT_ID"
    echo "(where PROJECT_ID is the desired project)"
else
    echo "Project Name: $GOOGLE_CLOUD_PROJECT"

PROJECT_ID=$(gcloud config get-value project)
SA_NAME="neptunesa"

# Create service account
    gcloud iam service-accounts create $SA_NAME --display-name="Neptune Function Service Account"

# Grant BigQuery Data Editor to this service account
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

# Grant Pub/Sub Subscriber (so function can receive messages)
    gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"

    gcloud storage buckets create gs://$GOOGLE_CLOUD_PROJECT"-bucket" --soft-delete-duration=0
    
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

    #gcloud services disable dataflow.googleapis.com --force
    #gcloud services enable dataflow.googleapis.com
    
    bq mk --location=US --dataset neptune
    bq mk --schema message:STRING -t neptune.rawmessages

    bq mk --table neptune.parsedmessages \
    id:STRING,ipaddress:STRING,action:STRING,accountnumber:STRING,actionid:INTEGER,name:STRING,actionby:STRING

    gcloud pubsub topics create neptune-activities
    gcloud pubsub subscriptions create neptune-activities-test --topic neptune-activities

    # Subscribe to moonbank

    gcloud pubsub subscriptions create neptune-activities \
    --topic projects/moonbank-neptune/topics/activities \
    --push-endpoint=https://pubsub.googleapis.com/v1/projects/$GOOGLE_CLOUD_PROJECT/topics/neptune-activities:publish



fi