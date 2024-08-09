import boto3
import json


def lambda_handler(event, context):
    print("lambda triggered")
    print(event)
    object_key = get_object_key(event)
    print(object_key)
    client = boto3.client('stepfunctions')

    input_json = json.dumps({'FileName': object_key})
    print(input_json)
    response = client.start_execution(
        stateMachineArn='arn:aws:states:eu-central-1:000000000000:stateMachine:swisscom-sfn',
        input=input_json,
    )
    print(response)

def get_object_key(event):
    key = event['Records'][0]['s3']['object']['key']
    print(key)
    bucket = event['Records'][0]['s3']['bucket']['name']
    print(bucket)
    return f'{bucket}/{key}'


