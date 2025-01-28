import http.client

def lambda_handler(event, context):
    try:
        # Establish a connection to a public URL
        conn = http.client.HTTPSConnection("www.google.com", timeout=5)
        conn.request("GET", "/")
        response = conn.getresponse()
        
        if response.status == 200:
            return {
                "statusCode": 200,
                "body": "Lambda function has internet access!"
            }
        else:
            return {
                "statusCode": response.status,
                "body": f"Unable to reach the internet. HTTP Status: {response.status}"
            }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": f"Error connecting to the internet: {str(e)}"
        }
