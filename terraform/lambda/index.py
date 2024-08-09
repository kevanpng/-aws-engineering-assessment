import boto3
import json


def lambda_handler(event, context):
    print("lambda triggered")
    print(event)
    # {'Records': [
    # {'eventVersion': '2.1',
    # 'eventSource': 'aws:s3',
    # 'awsRegion': 'eu-central-1',
    # 'eventTime': '2024-08-09T06:26:12.352Z',
    # 'eventName': 'ObjectCreated:Put',
    # 'userIdentity': {'principalId': 'AIDAJDPLRKLG7UEXAMPLE'},
    # 'requestParameters': {'sourceIPAddress': '127.0.0.1'},
    # 'responseElements': {'x-amz-request-id': '71914e40', 'x-amz-id-2': 'eftixk72aD6Ap51TnqcoF8eFidJG9Z/2'},
    # 's3': {
    #   's3SchemaVersion': '1.0', 'configurationId': 'lambda1',
    #   'bucket': {
    #       'name': 'swisscom-bucket-1', 'ownerIdentity': {'principalId': 'A3NL1KOZZKExample'},
    #       'arn': 'arn:aws:s3:::swisscom-bucket-1'
    #    },
    #   'object': {'key': 'README.md', 'sequencer': '0055AED6DCD90281E5', 'versionId': 'Wv_3zzpSQ6X62lq_8DpYcg', 'size': 1483, 'eTag': 'aea5bc4ed32903981ef6aa451bc12086'}}}]}
    object_key = get_object_key(event)
    print(object_key)
    client = boto3.client('stepfunctions')

    input_json = json.dumps({'FileName': object_key})
    print(input_json)
    response = client.start_execution(
        stateMachineArn='arn:aws:states:eu-central-1:000000000000:stateMachine:swisscom-sfn',
        input=input_json,
        # traceHeader='string'
    )
    print(response)

def get_object_key(event):
    key = event['Records'][0]['s3']['object']['key']
    print(key)
    bucket = event['Records'][0]['s3']['bucket']['name']
    print(bucket)
    return f'{bucket}/{key}'


