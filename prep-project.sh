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
    bq mk --location=US --dataset neptune
    bq mk --schema message:STRING -t neptune.rawmessages
    gcloud pubsub topics create np-activities-topic
    gcloud pubsub subscriptions create np-activities-subscription --topic np-activities-topic

    #mkdir np-activity && cd np-activity

    bq mk --table neptune.np_activities \
    id:STRING,ipaddress:STRING,action:STRING,accountnumber:STRING,actionid:INTEGER,name:STRING,actionby:STRING

fi