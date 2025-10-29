# Project Neptune Starter Code
# Assumes a dataset called neptune exists
# Assumes a table call rawmessages
# rawmessages schema - single column:  message:string
# TODO - break out based on schema

#================The origonal source code starts here ==============
#import base64
#from google.cloud import bigquery
#table_id = "neptune.rawmessages"
#
#
#def pubsub_to_bigquery(event, context):
#    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
#    print("Row To Insert: " + pubsub_message)
#    client = bigquery.Client()
#    table = client.get_table(table_id)
#    row_to_insert = [(pubsub_message,)]     # NOTE - the trailing comma is required for this case - it expects a tuple
#    errors = client.insert_rows(table, row_to_insert)
#    if errors == []:
#        print("Row Inserted: " + pubsub_message)

#================The working source code starts here ==============
import base64
from google.cloud import bigquery

def pubsub_to_bigquery(event, context):
    """Triggered from a message on a Pub/Sub topic."""
    try:
        if 'data' not in event:
            print("No data found in event.")
            return

        # Decode Pub/Sub message
        message = base64.b64decode(event['data']).decode('utf-8').strip()
        print(f"Received message: {message}")

        # Initialize BigQuery client
        client = bigquery.Client()

        # Insert raw message into rawmessages table
        raw_table = f"{client.project}.neptune.rawmessages"
        raw_record = {"message": message}
        raw_errors = client.insert_rows_json(raw_table, [raw_record])
        if raw_errors:
            print(f"BigQuery raw insertion errors: {raw_errors}")
        else:
            print(f"Inserted raw message: {message}")

        # Parse CSV message for parsedmessages table
        fields = message.split(',')
        if len(fields) != 7:
            print(f"Unexpected field count ({len(fields)}): {fields}")
            return

        parsed_record = {
            "id": fields[0],
            "ipaddress": fields[1],
            "action": fields[2],
            "accountnumber": fields[3],
            "actionid": int(fields[4]),
            "name": fields[5],
            "actionby": fields[6],
        }

        parsed_table = f"{client.project}.neptune.parsedmessages"
        parsed_errors = client.insert_rows_json(parsed_table, [parsed_record])
        if parsed_errors:
            print(f"BigQuery parsed insertion errors: {parsed_errors}")
        else:
            print(f"Inserted parsed record: {parsed_record}")

    except Exception as e:
        print(f"Error processing message: {e}")