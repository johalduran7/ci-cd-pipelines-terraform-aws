import requests

def lambda_handler(event, context):
    try:
        # Make a GET request to a public URL
        response = requests.get("https://www.google.com", timeout=5)
        
        if response.status_code == 200:
            return {
                "statusCode": 200,
                "body": "Lambda function has internet access!"
            }
        else:
            return {
                "statusCode": response.status_code,
                "body": f"Unable to reach the internet. HTTP Status: {response.status_code}"
            }
    except requests.exceptions.RequestException as e:
        return {
            "statusCode": 500,
            "body": f"Error connecting to the internet: {str(e)}"
        }
