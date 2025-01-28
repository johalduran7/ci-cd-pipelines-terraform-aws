import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    ssm = boto3.client('ssm')

    try:
        parameters = ssm.get_parameters_by_path(
            Path='/my-app/dev/',  # Specify the path to your parameters
            Recursive=True,
            WithDecryption=True  # Set to True if you want to decrypt SecureString parameters
        )

        # Convert datetime objects to strings
        for param in parameters['Parameters']:
            if 'LastModifiedDate' in param:
                param['LastModifiedDate'] = param['LastModifiedDate'].strftime('%Y-%m-%d %H:%M:%S')

        # Log and return the parameters
        print('Parameters:', parameters['Parameters'], 'Events: ',event)
        return {
            'statusCode': 200,
            'body': json.dumps(parameters['Parameters']),
            'parameters': json.dumps(event)
        }
    except Exception as e:
        print('Error retrieving parameters:', e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
