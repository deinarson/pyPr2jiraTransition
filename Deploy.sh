#!/bin/bash -x

# Define variables
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
echo "Using random suffix $RANDOM_SUFFIX"
RANDOM_SUFFIX=dale
RESOURCE_GROUP=fnkv-$RANDOM_SUFFIX-rg
FUNCTION_APP=fnkv-$RANDOM_SUFFIX-func
STORAGE_ACCOUNT=fnkv$RANDOM_SUFFIX
APP_PLAN=fnkv-$RANDOM_SUFFIX-plan
KEYVAULT=fnkv-$RANDOM_SUFFIX-kv
LOCATION=canadacentral
SUB_ID=$(az account show --query "id" | xargs)
REPO="git@dev.azure.com:/rcmn/DevOpsGit/_git/pr2jiraTransition"



#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

# Create the resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create the app service plan that will host our Function App
az appservice plan create --name $APP_PLAN --resource-group $RESOURCE_GROUP --sku B1 --is-linux

# Create the storage account that will serve as storage for our Function App
az storage account create --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --sku Standard_LRS
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT --query "connectionString" | xargs)

# There seems to be an issue with this command. Creating with an ARM template instead.
#az functionapp create Linux --runtime dotnet --plan $APP_PLAN -n $FUNCTION_APP --resource-group $RESOURCE_GROUP --storage-account $STORAGE_ACCOUNT
az group deployment create --name "Deploy$FUNCTION_APP" --template-file template.json \
    --resource-group $RESOURCE_GROUP \
    --parameters name=$FUNCTION_APP \
    --parameters storageConnectionString=$STORAGE_CONNECTION_STRING \
    --parameters hostingPlanName=$APP_PLAN \
    --parameters location=$LOCATION \
    --parameters serverFarmResourceGroup=$RESOURCE_GROUP \
    --parameters subscriptionId=$SUB_ID \
    --parameters hostingEnvironment=""

# Activate
PRINCIPAL_ID=$(az functionapp identity assign --name $FUNCTION_APP --resource-group $RESOURCE_GROUP --query principalId | xargs)

#az functionapp deployment source config-local-git --name "$FUNCTION_APP"      --resource-group $RESOURCE_GROUP

# Create the KV and assign the policy
az keyvault create --name $KEYVAULT -g $RESOURCE_GROUP 
SECRET_URI=$(az keyvault secret set --vault-name $KEYVAULT -n Secret --value 'MyFancySecret' --query id -o json | xargs)
az keyvault set-policy --name $KEYVAULT --object-id $PRINCIPAL_ID --secret-permissions get list

# Define the app settings for the function app
KV_REFERENCE='@Microsoft.KeyVault(SecretUri='$SECRET_URI')'
az webapp config appsettings set --name $FUNCTION_APP --resource-group $RESOURCE_GROUP --settings Secret=$KV_REFERENCE

# Build and publish the function
func azure functionapp publish $FUNCTION_APP --nozip

cat <<EOF
FUNCTION_APP=${FUNCTION_APP}
KEYVAULT=${KEYVAULT}
KV_REFERENCE=${KV_REFERENCE}

example: az keyvault secret set --vault-name $KEYVAULT -n Secret --value 'new pass' --query id -o json

git remote add ${FUNCTION_APP} https://${USER}:${PASS}@${FUNCTION_APP}.scm.azurewebsites.net/${FUNCTION_APP}.git
git push ${FUNCTION_APP} master

curl http://${FUNCTION_APP}.azurewebsites.net/api/returnsecret

EOF
