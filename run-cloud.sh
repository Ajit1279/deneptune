echo $GOOGLE_CLOUD_PROJECT

sudo pip3 install -r requirements.txt

#python3 main.py \
#  --project=$GOOGLE_CLOUD_PROJECT \
#  --region=us-central1 \
#  --input_topic=projects/$GOOGLE_CLOUD_PROJECT/topics/neptune-activities \
#  --bucket=$GOOGLE_CLOUD_PROJECT-bucket

  REGION="us-central1"
  TOPIC_NAME="neptune-activities"
  PROJECT_ID=$GOOGLE_CLOUD_PROJECT

gcloud beta services identity create \
  --service=pubsub.googleapis.com \
  --project=$GOOGLE_CLOUD_PROJECT

echo "pub-sub service account created successfully!"
gcloud iam service-accounts list --filter="gcp-sa-pubsub"

#Grant the token creator role to the Pub/Sub service account
PROJECT_NUMBER=$(gcloud projects describe $GOOGLE_CLOUD_PROJECT --format="value(projectNumber)")

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
echo "Granted Token Creator role to Pub/Sub service account!"

echo "Deploying Cloud Function..."
gcloud functions deploy pubsub_to_bigquery \
  --region=$REGION \
  --runtime=python312 \
  --entry-point=pubsub_to_bigquery \
  --trigger-topic=$TOPIC_NAME \
  --source=. \
  --project=$PROJECT_ID \
  --timeout=120s \
  --memory=256MB

echo "Cloud Function deployed successfully!"
echo "Verifying resources..."
gcloud functions describe pubsub_to_bigquery --region=$REGION
