echo $GOOGLE_CLOUD_PROJECT

sudo pip3 install -r requirements.txt

python3 main.py \
  --project=$GOOGLE_CLOUD_PROJECT \
  --region=us-central1 \
  --input_topic=projects/$GOOGLE_CLOUD_PROJECT/topics/np-activities \
  --bucket=$GOOGLE_CLOUD_PROJECT-bucket