#! /bin/bash
# MAKE SURE GCP PROJECT IS SET
# gcloud config set project PROJECT_ID
if [[ -z "${GOOGLE_CLOUD_PROJECT}" ]]; then
    echo "Project has not been set! Please run:"
    echo "   gcloud config set project PROJECT_ID"
    echo "(where PROJECT_ID is the desired project)"
else
    echo "Project Name: $GOOGLE_CLOUD_PROJECT"
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
    gcloud pubsub topics create neptune-activities
    gcloud pubsub subscriptions create neptune-activities-test --topic neptune-activities

    bq mk --table neptune.np_test \
    id:STRING,ipaddress:STRING,action:STRING,accountnumber:STRING,actionid:INTEGER,name:STRING,actionby:STRING

fi