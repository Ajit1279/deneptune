#!/usr/bin/env python3
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
import argparse

# ------------------------------
# Process each Pub/Sub message
# ------------------------------
def parse_csv_message(message):
    try:
        decoded = message.decode("utf-8") if isinstance(message, bytes) else message
        parts = decoded.strip().split(",")
        if len(parts) == 7:
            yield {
                "id": parts[0],
                "ipaddress": parts[1],
                "action": parts[2],
                "accountnumber": parts[3],
                "actionid": int(parts[4]),
                "name": parts[5],
                "actionby": parts[6]
            }
    except Exception as e:
        print(f"Error parsing message: {e}")

# ------------------------------
# Main pipeline
# ------------------------------
def run(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--input_topic", required=True)
    parser.add_argument("--bucket", required=True)
    known_args, pipeline_args = parser.parse_known_args(argv)

    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(StandardOptions).streaming = True

    p = beam.Pipeline(options=pipeline_options)

    (
        p
        | "ReadFromPubSub" >> beam.io.ReadFromPubSub(topic=known_args.input_topic)
        | "ParseMessage" >> beam.FlatMap(parse_csv_message)
        | "WriteToBigQuery" >> beam.io.WriteToBigQuery(
            table="np_test",
            dataset="neptune",
            project=known_args.project,
            schema={
                "fields": [
                    {"name": "id", "type": "STRING"},
                    {"name": "ipaddress", "type": "STRING"},
                    {"name": "action", "type": "STRING"},
                    {"name": "accountnumber", "type": "STRING"},
                    {"name": "actionid", "type": "INTEGER"},
                    {"name": "name", "type": "STRING"},
                    {"name": "actionby", "type": "STRING"}
                ]
            },
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
        )
    )

    p.run().wait_until_finish()

if __name__ == "__main__":
    run()
