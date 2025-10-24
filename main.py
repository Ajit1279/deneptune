# Project Neptune Starter Code
# Assumes a dataset called neptune exists
# Assumes a table call rawmessages
# rawmessages schema - single column:  message:string
# TODO - break out based on schema
import base64
from google.cloud import bigquery
from google.cloud import pubsub_v1
#import apache_beam as beam
#from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
#import argparse

raw_table_id = "neptune.rawmessages"
parsed_table_id = "neptune.parsedmessages"

def pubsub_to_bigquery(event, context):
    """
    Cloud Function to insert Pub/Sub messages:
    - raw CSV into rawmessages
    - parsed fields into parsedmessages
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    print(f"Received message: {pubsub_message}")

    client = bigquery.Client()

    # Insert raw message
    raw_row = [{"message": pubsub_message}]
    raw_errors = client.insert_rows_json(raw_table_id, raw_row)
    if raw_errors:
        print(f"Failed to insert into rawmessages: {raw_errors}")
    else:
        print("Inserted raw message successfully.")

    # Parse CSV and insert structured row
    try:
        parts = pubsub_message.strip().split(",")
        if len(parts) != 7:
            print(f"Invalid CSV message, skipping parsing: {pubsub_message}")
            return

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
        else:
            print("Inserted parsed row successfully.")

    except Exception as e:
        print(f"Error parsing or inserting message: {e}")
