#!/bin/bash
if [ $# -lt 4 ]; then
        echo ""
        echo "Usage: $0 <resourcegroup> <location> <storage account> <container> "
        echo ""
        exit 1
fi

RESOURCE_GROUP="${1}"
LOCATION="${2}"
STORAGE_ACCOUNT="${3}"
STORAGE_ACCOUNT_CONTAINER="${4}"

# prepare including max support
plus_one_year="-d +1year"
[[ $(uname) == "Darwin" ]] && plus_one_year="-v+1y"

# always start with interactive login
az login

# create resource group
az group create -l ${LOCATION} -n ${RESOURCE_GROUP}

# create storage account with Standard_RAGRS enabled (used for DRP during deployments)
az storage account create \
        --resource-group ${RESOURCE_GROUP} \
        --name ${STORAGE_ACCOUNT} \
        --location ${LOCATION} \
        --sku Standard_RAGRS

# get connection string storage account
STORAGE_ACCOUNT_CONNECTION_STRING=$(az storage account show-connection-string -g ${RESOURCE_GROUP} --name ${STORAGE_ACCOUNT} -o tsv)

# generate SAS token for container
STORAGE_SAS_TOKEN="?$(az storage container generate-sas --name ${STORAGE_ACCOUNT_CONTAINER} --account-name ${STORAGE_ACCOUNT} --connection-string "${STORAGE_ACCOUNT_CONNECTION_STRING}" --permissions lr --expiry $(date ${plus_one_year} -u +%Y-%m-%dT%H:%mZ) -o tsv)"
ESCAPED_SAS_TOKEN=$(echo ${STORAGE_SAS_TOKEN} | sed -e "s|\&|\\\&|g")

# create the storage container
az storage container create -n ${STORAGE_ACCOUNT_CONTAINER} --account-name ${STORAGE_ACCOUNT} --connection-string "${STORAGE_ACCOUNT_CONNECTION_STRING}"

# create an empty application image
tar czvf ./application-image-v1.tar.gz --files-from=/dev/null
# upload the files
az storage blob upload \
        --account-name ${STORAGE_ACCOUNT} \
        --container-name ${STORAGE_ACCOUNT_CONTAINER} \
        --connection-string ${STORAGE_ACCOUNT_CONNECTION_STRING} \
        --name "images/application-image-v1.tar.gz" \
        --file ./application-image-v1.tar.gz
# clean up
rm ./application-image-v1.tar.gz

# create our sas token file
echo "${STORAGE_SAS_TOKEN}" > ./sas-tokens.txt
# upload the files
az storage blob upload \
        --account-name ${STORAGE_ACCOUNT} \
        --container-name ${STORAGE_ACCOUNT_CONTAINER} \
        --connection-string ${STORAGE_ACCOUNT_CONNECTION_STRING} \
        --name "secrets/sas-tokens.txt" \
        --file ./sas-tokens.txt
# clean up
rm ./sas-tokens.txt

# create our principal and save the credentials
az ad sp create-for-rbac > ./deployment-credentials.json
# get info 
SUBSCRIPTION_ID=$(az account show | jq -r '.id')
SERVICE_PRINCIPAL_ID=$(cat ./deployment-credentials.json | jq -r '.appId')
# set owner role
az role assignment create \
        --role Owner \
        --scope /subscriptions/${SUBSCRIPTION_ID} \
        --assignee ${SERVICE_PRINCIPAL_ID}
          
# upload the files
az storage blob upload \
        --account-name ${STORAGE_ACCOUNT} \
        --container-name ${STORAGE_ACCOUNT_CONTAINER} \
        --connection-string ${STORAGE_ACCOUNT_CONNECTION_STRING} \
        --name "secrets/deployment-credentials.json" \
        --file ./deployment-credentials.json
# clean up
rm ./deployment-credentials.json
