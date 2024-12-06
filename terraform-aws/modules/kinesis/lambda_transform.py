import boto3
import os
import base64
from datetime import datetime, timedelta

# Initialize S3 client
s3_client = boto3.client("s3")

def lambda_handler(event, context):
    bucket_name = os.environ["BUCKET_NAME"]

    processed_records = []

    # Eastern Time offset (UTC-5)
    eastern_offset = timedelta(hours=-5)

    for record in event["records"]:
        try:
            # Decode the input record
            original_message = base64.b64decode(record["data"]).decode("utf-8")
            
            # Generate transformed message with ET timestamp
            utc_now = datetime.utcnow()
            current_time_et = utc_now + eastern_offset
            current_time_et_str = current_time_et.strftime("%I:%M %p ET")
            transformed_message = f"{original_message} processed_by_lambda at {current_time_et_str}"
            
            # Generate file name
            file_name = f"{original_message.lower().replace(' ', '')}_processed.txt"

            # Upload to S3
            s3_client.put_object(
                Bucket=bucket_name,
                Key=file_name,
                Body=transformed_message
            )
            
            # Encode the transformed message back to Base64 for Firehose
            encoded_data = base64.b64encode(transformed_message.encode("utf-8")).decode("utf-8")
            
            # Add to processed records
            processed_records.append({
                "recordId": record["recordId"],
                "result": "Ok",
                "data": encoded_data
            })
        except Exception as e:
            print(f"Error processing record {record['recordId']}: {e}")
            # If an error occurs, mark the record as Dropped
            processed_records.append({
                "recordId": record["recordId"],
                "result": "Dropped",
                "data": record["data"]
            })
    
    return {"records": processed_records}
