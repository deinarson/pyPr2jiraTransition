
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
secret_name='kv-demo-secret-name'
vault_name='kv-demo-uuid'
vault_rg='kv-keyvault-demo'
vault_rg_location='canadacentral'
WEBAPP_GIT_PASS="kv-demo-random-pass"
web_app_name="kv-demo-webapp"


API_KEYNAME="API-TOKEN"
API_TOKEN="kv-demo-token"


export KEY_VAULT_URI="https://${vault_name}.vault.azure.net"
export AZURE_CLIENT_SECRET='kv-demo-sp-webapp-secret'
export AZURE_CLIENT_SECRET_NAME='kv-demo-sp-secret_name'
export AZURE_SUBSCRIPTION_ID=$(az account show --query=id| xargs)
export AZURE_TENANT_ID=$(az account  show  --query=tenantId  | xargs )
# if web app is already created
#  export AZURE_CLIENT_ID=$( az ad app list --query "[?displayName=='${web_app_name}'].appId" --output tsv |  grep -v 'In a')

az keyvault show -n "${vault_name}"
```

## 2: Create WebApp
``` bash 
az group create --name "${vault_rg}" --location "${vault_rg_location}"
# az webapp deployment user set --user-name "${web_app_name}" --password "${WEBAPP_GIT_PASS}"
 
az appservice plan create --name "${web_app_name}"-sp --resource-group "${vault_rg}" --sku B1 --is-linux


az webapp create --resource-group "${vault_rg}" --plan "${web_app_name}"-sp --name "${web_app_name}" --runtime "PYTHON|3.7" --deployment-local-git
az webapp identity assign --name "${web_app_name}" --resource-group "${vault_rg}"
```


## 3: Create Keyvault, and secrets

``` bash
az provider register -n Microsoft.KeyVault
 
az keyvault create --name "${vault_name}" --resource-group "${vault_rg}" --location "${vault_rg_location}"
az keyvault secret set --vault-name "${vault_name}" --name "${AZURE_CLIENT_SECRET}" --value "${AZURE_CLIENT_SECRET_NAME}"
az keyvault secret set --vault-name "${vault_name}" --name "${API_KEYNAME}" --value "${API_TOKEN}"
# az keyvault key list --vault-name "${vault_name}"
# az keyvault key create --vault-name "${vault_name}" --name "${secret_name}" --protection software
az keyvault secret list --vault-name "${vault_name}"
# az keyvault certificate list --vault-name "${vault_name}"
```

## 4: Create SP RBAC for WebApp

``` bash
az ad sp create-for-rbac -n "${web_app_name}.vault.azure.net" --password "${AZURE_CLIENT_SECRET}" --skip-assignment

# Get the sp appId
export AZURE_CLIENT_ID=$(az ad sp list | grep -v 'In a' | jq ".[] | select( .appDisplayName == \"${web_app_name}\" ) .appId"  | xargs )

az keyvault set-policy --name "${vault_name}" --spn "${AZURE_CLIENT_ID}" --key-permissions decrypt sign
 
az keyvault set-policy --name "${vault_name}" --spn "${AZURE_CLIENT_ID}" --secret-permissions get
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
  echo CONFIRMING
  az webapp config  appsettings list -g "${vault_rg}"  -n "${web_app_name}"
```

## 6: Copy example code and test locally
``` bash
git clone git@ssh.dev.azure.com:v3/rcmn/DevOpsGit/PythonKeyvaultExample
cd  PythonKeyvaultExample
make image
make test
./application.py 

# in another terminal type
docker exec -i -t py curl http://127.0.0.1:5000

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

# The End

<hr>


## Appendix I: Variables required to run local test
Microsoft has really messed this up, they use stdout for warnings 
``` bash

vault_name='kv-demo'
web_app_name="kv-demo-webapp"

export AZURE_CLIENT_SECRET='kv-demo-sp-webapp-secret'
export KEY_VAULT_URI="https://${vault_name}.vault.azure.net"
# for some reason AZ messes this up, you will want to review what you get
export AZURE_TENANT_ID=$(az account  show  --query=tenantId | xargs)
export AZURE_SUBSCRIPTION_ID=$(az account show --query=id  | xargs )
export AZURE_CLIENT_ID=$( az ad app list --query "[?displayName=='${web_app_name}'].appId" --output tsv |  grep -v 'In a')


az keyvault set-policy --name "${vault_name}" --object-id ${object_id} --secret-permissions get


# Get web app source code
USER='user'
PASS="passowrd"
URL="https://\$${USER}:${PASS}@${USER}.scm.azurewebsites.net/${USER}.git"
git clone $URL
```


## Appendix II notes

``` bash
# List App settings
az webapp config  appsettings list -g $vault_rg  -n $web_app_name 
# Modify APP Settings in CLI
az webapp config  appsettings set --settings  'KEY_VAULT_URI=https://${vault_name}".vault.azure.net'    -g $vault_rg  -n $web_app_name 

# web app
az webapp log tail --name ${web_app_name}  --resource-group ${vault_rg}
az webapp show  --name ${web_app_name}  --resource-group ${vault_rg}

# list keys, then show a specific key 
az keyvault list
az keyvault show -n "${vault_name}" 

az keyvault secret list --vault-name "${vault_name}" 
az keyvault secret show  --vault-name "${vault_name}" --name API-TOKEN

```
