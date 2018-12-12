# Create Python WebApp using KeyVault
The following is a modified version of the MSI example code.

1. Set variables
1. Create WebApp
1. Create Keyvault, and secrets
1. Create SP RBAC for WebApp
1. Update Webapp "App settings"
1. Copy example code and test locally
1. Push example code to WebApp and test


## 1: Set Variables: Initial config settings

``` bash 
vault_name='dale-demo'
vault_rg='dale-keyvault-demo'
vault_rg_location='canadacentral'
web_app_name="dale-demo-webapp"
secret_name='dale-demo-secret-name'
WEBAPP_GIT_PASS="dale-demo-random-pass"

API_KEYNAME="API-TOKEN"
API_TOKEN="dale-demo-token"

export AZURE_CLIENT_SECRET='dale-demo-sp-webapp-secret'
export AZURE_TENANT_ID=$(az account show --query=tenantId)
export AZURE_SUBSCRIPTION_ID=$(az account show --query=id)
export KEY_VAULT_URI="https://${vault_name}.vault.azure.net"
```

## 2: Create WebApp
``` bash 
az webapp deployment user set --user-name "${web_app_name}" --password "${WEBAPP_GIT_PASS}"
az appservice plan create --name "${web_app_name}"-sp --resource-group "${vault_rg}" --sku B1 --is-linux
az webapp create --resource-group "${vault_rg}" --plan "${web_app_name}"-sp --name "${web_app_name}" --runtime "PYTHON|3.7" --deployment-local-git
az webapp identity assign --name "${web_app_name}" --resource-group "${vault_rg}"
```


## 3: Create Keyvault, and secrets

``` bash
az provider register -n Microsoft.KeyVault
 
az keyvault create --name "${vault_name}" --resource-group "${vault_rg}" --location 'canadacentral'
az keyvault secret set --vault-name "${vault_name}" --name "${AZURE_CLIENT_SECRET}" --value "${secret}"
az keyvault secret set --vault-name "${vault_name}" --name "${API_KEYNAME}" --value "${API_TOKEN}"
# az keyvault key list --vault-name "${vault_name}"
# az keyvault key create --vault-name "${vault_name}" --name "${secret_name}" --protection software
az keyvault secret list --vault-name "${vault_name}"
# az keyvault certificate list --vault-name "${vault_name}"
```

## 4: Create SP RBAC for WebApp

``` bash
az ad sp create-for-rbac -n "${web_app_name}" --password "${AZURE_CLIENT_SECRET}" --skip-assignment

# Get the sp appId
export AZURE_CLIENT_ID=$(az ad sp list | jq '.[] | select( .appDisplayName == "${web_app_name}" ) .appId')
az keyvault set-policy --name "${vault_name}" --spn "${AZURE_CLIENT_ID}" --key-permissions decrypt sign
 
az keyvault set-policy --name "${vault_name}" --spn "${AZURE_CLIENT_ID}" --secret-permissions get

# Get Tenant ID from app
export AZURE_TENANT_ID=$(az ad sp list | grep -v 'In a' | jq ".[] | select( .appDisplayName == \"${web_app_name}\" ) .appOwnerTenantId")
  
export KEY_VAULT_URI=https://"${vault_name}".vault.azure.net
```




## 5: Update Webapp "App settings"

Using values from previous steps

``` bash   
  for kv in "AZURE_CLIENT_ID=${AZURE_CLIENT_ID}"             \
            "AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}"  \
            "AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}"      \
            "KEY_VAULT_URI=${KEY_VAULT_URI}"                  \
            "AZURE_TENANT_ID=${AZURE_TENANT_ID}" 
  do 
    az webapp config  appsettings set -g "${vault_rg}"  -n "${web_app_name}"  --settings $kv
  done 
```

## 6: Copy example code and test locally
``` bash
git clone git@ssh.dev.azure.com:v3/rcmn/DevOpsGit/PythonKeyvaultExample
cd  PythonKeyvaultExample
make image
make test
./msi.py

# in another terminal type
docker exec -i -t py curl http://127.0.0.1:500

```
## 7: Push example code to WebApp and test
``` bash
git remote add azure https://${web_app_name}@${web_app_name}.scm.azurewebsites.net/${web_app_name}.git
git push azure master
# you will be prompted for "${WEBAPP_GIT_PASS}"
# wait a bit and 
curl http://${web_app_name}.scm.azurewebsites.net
```





<hr>

# the end

<hr>

## Appendix

``` bash
# List App settings
az webapp config  appsettings list -g $vault_rg  -n $web_app_name 
# Modify APP Settings in CLI
az webapp config  appsettings set --settings  'KEY_VAULT_URI=https://${vault_name}".vault.azure.net'    -g $vault_rg  -n $web_app_name 

# list keys, then show a specific key 
az keyvault secret list --vault-name "${vault_name}" 
az keyvault secret show  --vault-name "${vault_name}" --name JIRA-TOKEN 
```


## Variables required to run local test
Microsoft has really messed this up, they use stdout for warnings 
``` bash
vault_name='daleVault-1539368722'
web_app_name="PythonJiraAPI"

export AZURE_CLIENT_SECRET='PythonJiraApikey'
export KEY_VAULT_URI="https://${vault_name}.vault.azure.net"
# for some reason AZ messes this up, you will want to review what you get
export AZURE_TENANT_ID=$(az account  show  --query=tenantId | tr -d \" )
export AZURE_SUBSCRIPTION_ID=$(az account show --query=id  | tr -d \" )
export AZURE_CLIENT_ID=$( az ad app list --query "[?displayName=='PythonJiraAPI'].appId" --output tsv |  grep -v 'In a')
```