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
    #SA_NAME="neptunesa"
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

# Commented out as the requirement is to use an default service account
# Create service account
#    gcloud iam service-accounts create $SA_NAME --display-name="Neptune Function Service Account"

    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
    echo $PROJECT_NUMBER

    COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

    gcloud iam service-accounts add-iam-policy-binding $COMPUTE_SA \
    --member="user:$(gcloud config get-value account)" \
    --role="roles/iam.serviceAccountTokenCreator"

    gcloud config set auth/impersonate_service_account $COMPUTE_SA

# Grant BigQuery Data Editor to the default service account
    gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

# Grant Pub/Sub Subscriber (so function can receive messages)
    gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/pubsub.subscriber"

    gcloud storage buckets create gs://$GOOGLE_CLOUD_PROJECT"-bucket" --soft-delete-duration=0

    #gcloud services disable dataflow.googleapis.com --force
    #gcloud services enable dataflow.googleapis.com
    
    bq mk --location=US --dataset $DATASET 

    bq mk --schema message:STRING -t $DATASET.rawmessages

    bq mk --table $DATASET.parsedmessages \
    id:STRING,ipaddress:STRING,action:STRING,accountnumber:STRING,actionid:INTEGER,name:STRING,actionby:STRING

    gcloud pubsub topics create neptune-activities
    gcloud pubsub subscriptions create neptune-activities-test --topic neptune-activities

    # Subscribe to moonbank

    gcloud pubsub subscriptions create neptune-activities \
    --topic projects/moonbank-neptune/topics/activities \
    --push-endpoint=https://pubsub.googleapis.com/v1/projects/$GOOGLE_CLOUD_PROJECT/topics/neptune-activities:publish

    #gcloud iam service-accounts add-iam-policy-binding \
    #$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
    #--member="serviceAccount:$PROJECT_ID@appspot.gserviceaccount.com" \
    #--role="roles/iam.serviceAccountTokenCreator"
  
    bq update --dataset \
    --add_iam_member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com:roles/bigquery.dataEditor" \
    $DATASET:neptune

fi