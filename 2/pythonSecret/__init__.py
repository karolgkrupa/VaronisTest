import logging
import json

import azure.functions as func
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')
    name = req.params.get('name')
    if not name:
        return func.HttpResponse("Bad request you need to pass name", status_code=400)
    credential = DefaultAzureCredential()
    logging.info('DefaultAzureCredential')
    kv = "VaronisAssignmentKv01", "VaronisAssignmentKv02", "VaronisAssignmentKv03"
    response = []
    for keyVaultName in kv:
        KVUri = f"https://{keyVaultName}.vault.azure.net"
        client = SecretClient(vault_url=KVUri, credential=credential)
        try:
            data = client.get_secret(name)
            response.append({'keyVaultName': keyVaultName, 'secretName': name, 'secretValue': data.value,
                             'createdOn': data.properties.created_on.isoformat()})
            logging.info(
                f'Keyvault Name: {keyVaultName}\nSecret name: {name}\nSecret value: {data.value}\nSecret created on: {data.properties.created_on}\n')
        except Exception as e:
            response.append({'keyVaultName': keyVaultName, 'secretName': name, 'error': str(e)})
        client.close()
    return func.HttpResponse(json.dumps(response))
