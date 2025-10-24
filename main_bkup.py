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
test_table_id = "neptune.parsedmessages"


def pubsub_to_bigquery(event, context):
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    print("Row To Insert: " + pubsub_message)
    client = bigquery.Client()
    table = client.get_table(raw_table_id)
    row_to_insert = [(pubsub_message,)]     # NOTE - the trailing comma is required for this case - it expects a tuple
    errors = client.insert_rows(table, row_to_insert)
    if errors == []:
        print("Row Inserted: " + pubsub_message)


# ------------------------------
# Process each Pub/Sub message
# ------------------------------
#def parse_csv_message(message):
#    try:
#        decoded = message.decode("utf-8") if isinstance(message, bytes) else message
#        parts = decoded.strip().split(",")
#        if len(parts) == 7:
#            yield {
#                "id": parts[0],
#                "ipaddress": parts[1],
#                "action": parts[2],
#                "accountnumber": parts[3],
#                "actionid": int(parts[4]),
#                "name": parts[5],
#                "actionby": parts[6]
#            }
#    except Exception as e:
#        print(f"Error parsing message: {e}")
