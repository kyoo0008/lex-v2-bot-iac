# To-do : lambda tf(iam => wisdom:*)
import json
import boto3
import json

def handler(event, context):

    # amazon qconnect create session
    client = boto3.client('qconnect', region_name='ap-northeast-2')
    localeId = event["Details"]["Parameters"]["localeId"]
    contactId = event["Details"]["Parameters"]["contactId"]
    list_assistants_response=client.list_assistants()
    assistantId = ""
    for assistant in list_assistants_response.get("assistantSummaries", []):
        if localeId.replace("-","_") in assistant.get("name", ""):
            assistantId = assistant.get("assistantId", "")
            break


    response = client.create_session(
        assistantId=assistantId,
        name=f"{contactId}_{localeId}"
    )

    # TODO implement
    return {
        "sessionArn": response.get("session", {}).get("sessionArn", "")
    }

