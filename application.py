#!/usr/bin/env python
import os


from flask import Flask
app = Flask(__name__)

from azure.keyvault import KeyVaultClient
from msrestazure.azure_active_directory import MSIAuthentication, ServicePrincipalCredentials

KEY_VAULT_URI = os.environ['KEY_VAULT_URI']

def get_key_vault_credentials():
    """This tries to get a token using MSI, or fallback to SP env variables.
    """
    if "APPSETTING_WEBSITE_SITE_NAME" in os.environ:
        return MSIAuthentication(
            resource='https://vault.azure.net'
        )
    else:
        return ServicePrincipalCredentials(
            client_id=os.environ['AZURE_CLIENT_ID'],
            secret=os.environ['AZURE_CLIENT_SECRET'],
            tenant=os.environ['AZURE_TENANT_ID'],
            resource='https://vault.azure.net'
        )

def run_example():
    """MSI Authentication example."""

    # Get credentials
    credentials = get_key_vault_credentials()

    # Create a KeyVault client
    key_vault_client = KeyVaultClient(
        credentials
    )

    key_vault_uri = os.environ.get("KEY_VAULT_URI", KEY_VAULT_URI)

    #  list secrets in a vault
    # az keyvault secret list --vault-name "${vault_name}"
    secret = key_vault_client.get_secret(
        key_vault_uri,     # Your KeyVault URL
        'API-TOKEN',       # Name of your secret. If you followed the README 'secret' should exists
        ""                 # The version of the secret. Empty string for latest
    )
    return "Working! API secret is {}\n".format(secret.value)


@app.route('/')
def hello_world():
    try:
        return run_example()
    except Exception as err:
        return str(err)

@app.route('/ping')
def ping():
    client_id="not present in env"
    tenant="not present in env"
    secret="not present in env"

    if 'AZURE_CLIENT_ID' in os.environ:
        client_id=os.environ['AZURE_CLIENT_ID']
    if 'AZURE_CLIENT_SECRET' in os.environ:
        secret=os.environ['AZURE_CLIENT_SECRET']
    if 'AZURE_TENANT_ID' in os.environ:
        tenant=os.environ['AZURE_TENANT_ID']
    if 'KEY_VAULT_URI' in os.environ:
        kv_uri=os.environ['KEY_VAULT_URI']

    responce = "tenant=" + tenant + ", secret=" + secret + ", client_id=" + client_id + ", KEY_VAULT_URI=" + kv_uri
    return responce

if __name__ == '__main__':
  app.run()
