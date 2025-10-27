#====================================
import base64
import json
import os
from google.cloud import bigquery

# Get Project A ID and Dataset ID from environment variables
PROJECT_A_ID = os.environ.get('PROJECT_A_ID')
DATASET_ID = os.environ.get('DATASET_ID')

raw_table_id = f"{PROJECT_A_ID}.{DATASET_ID}.rawmessages"
parsed_table_id = f"{PROJECT_A_ID}.{DATASET_ID}.parsedmessages"

def pubsub_to_bigquery(request):
    """
    HTTP Cloud Function to insert Pub/Sub messages (via push subscription).
    """
    request_json = request.get_json(silent=True)
    
    # 1. Extract the Pub/Sub message data from the push request body
    if not request_json or 'message' not in request_json or 'data' not in request_json['message']:
        print("Invalid Pub/Sub push message format.")
        return 'Invalid Pub/Sub message', 400

    try:
        # The Pub/Sub data is base64 encoded within the 'message' body
        pubsub_message_data = request_json['message']['data']
        pubsub_message = base64.b64decode(pubsub_message_data).decode('utf-8')
        print(f"Received message: {pubsub_message}")
    except Exception as e:
        print(f"Error decoding message: {e}")
        return 'Error decoding message', 500

    client = bigquery.Client()

    # 2. Insert raw message
    raw_row = [{"message": pubsub_message}]
    raw_errors = client.insert_rows_json(raw_table_id, raw_row)
    if raw_errors:
        print(f"Failed to insert into rawmessages: {raw_errors}")
    else:
        print("Inserted raw message successfully.")

    # 3. Parse CSV and insert structured row
    try:
        parts = pubsub_message.strip().split(",")
        if len(parts) != 7:
            print(f"Invalid CSV message, skipping parsing: {pubsub_message}")
            return 'OK', 200 # Still return OK so Pub/Sub doesn't retry

        parsed_row = [{
            "id": parts[0],
            "ipaddress": parts[1],
            "action": parts[2],
            "accountnumber": parts[3],
            "actionid": int(parts[4]),
            "name": parts[5],
            "actionby": parts[6]
        }]
        parsed_errors = client.insert_rows_json(parsed_table_id, parsed_row)
        if parsed_errors:
            print(f"Failed to insert into parsedmessages: {parsed_errors}")
            # Consider returning 500 here if BQ insertion failure should trigger a retry
            return 'BigQuery Insert Failed', 500 
        else:
            print("Inserted parsed row successfully.")

    except Exception as e:
        print(f"Error parsing or inserting message: {e}")
        return 'Internal Error', 500
    
    return 'OK', 200 # Success response for Pub/Sub