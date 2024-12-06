import boto3
import os
import logging
import time
import json  # For structuring the log events as JSON

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize the EC2 and CloudWatch Logs clients
ec2_client = boto3.client('ec2')
cloudwatch_client = boto3.client('logs')

# Environment variables
log_group = os.environ.get('log_group')
log_stream = os.environ.get('log_stream')

def lambda_handler(event, context):
    """
    Terminate an EC2 instance based on the instance ID provided in the environment variables.
    """
    # Get the instance ID from the environment variables
    instance_id = os.environ.get('instance_id')

    if not instance_id:
        logger.error("Instance ID is not set in environment variables.")
        return {
            'statusCode': 500,
            'body': 'Instance ID not found in environment variables.'
        }

    try:
        logger.info(f"Attempting to terminate EC2 instance: {instance_id}")

        # Terminate the EC2 instance
        response = ec2_client.terminate_instances(InstanceIds=[instance_id])

        # Log the response for debugging purposes
        logger.info(f"Termination response: {response}")

        # Check if the log stream already exists
        try:
            cloudwatch_client.describe_log_streams(
                logGroupName=log_group,
                logStreamNamePrefix=log_stream
            )
        except cloudwatch_client.exceptions.ResourceNotFoundException:
            # Create the log stream if it does not exist
            cloudwatch_client.create_log_stream(
                logGroupName=log_group,
                logStreamName=log_stream
            )

        # Structure log events as JSON with 'LogType' = 'lambda'
        log_event = {
            'timestamp': int(round(time.time() * 1000)),  # Timestamp in milliseconds
            'message': json.dumps({
                'LogType': 'lambda',
                'Message': f"EC2 instance {instance_id} was terminated successfully."
            })
        }

        # Put the log event in CloudWatch Logs
        cloudwatch_client.put_log_events(
            logGroupName=log_group,
            logStreamName=log_stream,
            logEvents=[log_event]
        )

        return {
            'statusCode': 200,
            'body': f"Successfully terminated EC2 instance: {instance_id}"
        }

    except Exception as e:
        logger.error(f"Failed to terminate EC2 instance: {instance_id}. Error: {e}")
        return {
            'statusCode': 500,
            'body': f"Error terminating EC2 instance: {e}"
        }
