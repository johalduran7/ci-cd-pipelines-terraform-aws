import json
from datetime import datetime

def lambda_handler(event, context):
    print("event: ", event)

    return {
        'statusCode': 200,
        'body': json.dumps(event['Records'][0]['body']),
    }
