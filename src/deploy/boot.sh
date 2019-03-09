#!/bin/bash

# get our stuff
. ./utils.sh
. ./environment.sh
. ./api-versions.sh

# start clean
clear

# variables comes here
BOOTSTRAP_STORAGE_ACCOUNT=bootstrapsa$UNIQUE_NAME_FIX

# create the resource group
display_progress "Creating resource group ${RESOURCE_GROUP}"
az group create -n ${RESOURCE_GROUP} -l ${LOCATION}

# create storage account
display_progress "Creating bootstrap account ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
az storage account create -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -l ${LOCATION} --sku Standard_LRS

# get connection string storage account
display_progress "Retrieving connection string for ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
BOOTSTRAP_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} -o tsv)

# create the storage container
display_progress "Creating bootstrap container in storage account"
az storage container create -n bootstrap --account-name ${BOOTSTRAP_STORAGE_ACCOUNT} --connection-string "${BOOTSTRAP_STORAGE_CONNECTION_STRING}"

# create the SAS token to access it and upload files
display_progress "Generating bootstrap SAS tokens"

BOOTSTRAP_STORAGE_ACCOUNT_KEY=$(az storage account keys list --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} --account-name ${BOOTSTRAP_STORAGE_ACCOUNT}  | jq -r '.[0].value')
BOOTSTRAP_STORAGE_SAS_TOKEN="?$(az storage container generate-sas -n bootstrap --account-name ${BOOTSTRAP_STORAGE_ACCOUNT} --connection-string "${BOOTSTRAP_STORAGE_CONNECTION_STRING}" --permissions lr --expiry $(date ${plus_one_year} -u +%Y-%m-%dT%H:%mZ) -o tsv)"
ESCAPED_BOOTSTRAP_STORAGE_SAS_TOKEN=$(echo ${BOOTSTRAP_STORAGE_SAS_TOKEN} | sed -e "s|\&|\\\&|g")

# check if we should create the image
if [ "${CUSTOM_IMAGE_URI}" == "none" ]; then
    display_progress "Preparing custom image"
    # create image
    ./create-custom-image.sh \
        "${PROJECT_NAME}-host-img-${UNIQUE_NAME_FIX}" \
        "${BOOTSTRAP_STORAGE_ACCOUNT}" \
        "${TENANT_ID}" \
        "${SERVICE_PRINCIPAL_ID}" \
        "${SERVICE_PRINCIPAL_KEY}" \
        "${SUBSCRIPTION_ID}" \
        "${RESOURCE_GROUP}" \
        "${LOCATION}" &> ${LOG_DIR}/custom-image.build.log
    # get output 
    CUSTOM_IMAGE_URI="$(cat ./manifest.json | jq -r '.builds[0].artifact_id')"
fi

# get right url
display_progress "Retrieving final destination uri for uploading files"
BLOB_BASE_URL=$(az storage account show -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -o json --query="primaryEndpoints.blob" -o tsv)

# check to upload local files in current directory
display_progress "Uploading common files to bootstrap account"
upload_files ${BOOTSTRAP_STORAGE_CONNECTION_STRING} bootstrap .

# check to upload local files in deployment model directory
display_progress "Uploading ${DEPLOYMENT_MODEL} specific files to bootstrap account"
upload_files ${BOOTSTRAP_STORAGE_CONNECTION_STRING} bootstrap ./${DEPLOYMENT_MODEL}

# systems to build
display_progress "Building systems"
ACTIVE_PROCESSES=()
BUILDS="host services"
# go over each function app
for BUILD in $BUILDS; do
    # Preparing services
    pusha ../scripts/${BUILD}
    # Building services
    display_progress "Building ${BUILD}"
    ./build.sh ${BOOTSTRAP_STORAGE_CONNECTION_STRING} bootstrap &> ${LOG_DIR}/${BUILD}.build.log &
    # add to track
    ACTIVE_PROCESSES+=($!)
    # cleanup
    popa
done

# wait until things settled down
display_progress "Waiting until builds are completed"
wait_all_processes ${ACTIVE_PROCESSES[@]}
display_progress "Builds are completed"
ACTIVE_PROCESSES=()

# create the consul principal
# display_progress "Creating consul principal"
# CONSUL_PRINCIPAL_DATA=$(az ad sp create-for-rbac)
# CONSUL_CLIENT_ID=$(echo "${CONSUL_PRINCIPAL_DATA}" | jq -r '.appId')
# CONSUL_CLIENT_KEY=$(echo "${CONSUL_PRINCIPAL_DATA}" | jq -r '.password')
# CONSUL_TENANT_ID=$(echo "${CONSUL_PRINCIPAL_DATA}" | jq -r '.tenant')

# HACK: currently we use the deployment credentials as the consul one
CONSUL_TENANT_ID=${TENANT_ID}
CONSUL_CLIENT_ID=${SERVICE_PRINCIPAL_ID}
CONSUL_CLIENT_KEY=${SERVICE_PRINCIPAL_KEY}

# main deployment
if [[ "${DEPLOYMENT_MODEL}" == "arm" ]]; then
    # enter 
    pushd ./${DEPLOYMENT_MODEL}
    # Mark & as escaped characters in SAS Token
    MAIN_URI="${BLOB_BASE_URL}bootstrap/main.json${BOOTSTRAP_STORAGE_SAS_TOKEN}"
    # replace with right versions
    replace_versions main.parameters.template.json main.parameters.json
    # replace additional parameters in parameter file
    sed -i.bak \
    -e "s|<uniqueNameFix>|${UNIQUE_NAME_FIX}|" \
    -e "s|<operationMode>|${OPERATION_MODE}|" \
    -e "s|<projectName>|${PROJECT_NAME}|" \
    -e "s|<deploymentPrincipalObjectId>|${SERVICE_PRINCIPAL_OID}|" \
    -e "s|<bootstrapStorageAccount>|${BOOTSTRAP_STORAGE_ACCOUNT}|" \
    -e "s|<bootstrapStorageAccountKey>|${BOOTSTRAP_STORAGE_ACCOUNT_KEY}|" \
    -e "s|<bootstrapStorageAccountSas>|${ESCAPED_BOOTSTRAP_STORAGE_SAS_TOKEN}|" \
    -e "s|<bootstrapStorageAccountUrl>|${BLOB_BASE_URL}|" \
    -e "s|<customImageUri>|${CUSTOM_IMAGE_URI}|" \
    -e "s|<consulTenantId>|${CONSUL_TENANT_ID}|" \
    -e "s|<consulClientId>|${CONSUL_CLIENT_ID}|" \
    -e "s|<consulClientKey>|${CONSUL_CLIENT_KEY}|" \
    main.parameters.json

    # create the main deployment either in background or not
    display_progress "Deploying main template into resource group using ${DEPLOYMENT_MODEL}"
    az group deployment create -g ${RESOURCE_GROUP} --template-uri ${MAIN_URI} --parameters @main.parameters.json --output json > main.output.json
    # all done
    display_progress "Main deployment completed"
    MAIN_OUTPUT=$(cat main.output.json)
    cat main.output.json &> ${LOG_DIR}/main.arm.deploy.log
    # get services name and other usefull info
    SERVICES_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.servicesId.value')
    SERVICES_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.servicesPrincipalId.value')
    STATUS_TOPIC_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.statusTopicId.value')
    STORAGE_ACCOUNT_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.storageAccountId.value')
    KEY_VAULT_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.keyVaultId.value')
    KEY_VAULT_URI=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.keyVaultUri.value')
    
    # get the api subsystem settings
    API_LB_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.apiLoadBalancerId.value')
    API_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.apiVmssId.value')
    API_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.apiVmssPrincipalId.value')
    API_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.apiVmssAutoScaleId.value')

    # get the coredb subsystem settings
    COREDB_LB_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.coredbLoadBalancerId.value')
    COREDB_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.coredbVmssId.value')
    COREDB_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.coredbVmssPrincipalId.value')
    COREDB_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.coredbVmssAutoScaleId.value')

    # get the mds subsystem settings
    MDS_LB_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.mdsLoadBalancerId.value')
    MDS_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.mdsVmssId.value')
    MDS_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.mdsVmssPrincipalId.value')
    MDS_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.mdsVmssAutoScaleId.value')

    # get the consul subsystem settings
    CONSUL_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.consulVmssId.value')
    CONSUL_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.consulVmssPrincipalId.value')
    CONSUL_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.consulVmssAutoScaleId.value')

    # leave
    popd
fi

if [[ "${DEPLOYMENT_MODEL}" == "tf" ]]; then
    # enter 
    pushd ./${DEPLOYMENT_MODEL}
    # create the main deployment either in background or not
    display_progress "Deploying main template into resource group using ${DEPLOYMENT_MODEL}"
    # replace additional parameters in parameter file
    sed -i.bak \
    -e "s|<unique-name-fix>|${UNIQUE_NAME_FIX}|" \
    -e "s|<operation-mode>|${OPERATION_MODE}|" \
    -e "s|<project-name>|${PROJECT_NAME}|" \
    -e "s|<resource-group>|${RESOURCE_GROUP}|" \
    -e "s|<location>|${LOCATION}|" \
    -e "s|<subscription-id>|${SUBSCRIPTION_ID}|" \
    -e "s|<tenant-id>|${TENANT_ID}|" \
    -e "s|<client-id>|${SERVICE_PRINCIPAL_ID}|" \
    -e "s|<client-secret>|${SERVICE_PRINCIPAL_KEY}|" \
    -e "s|<boot-storage-account-uri>|${BLOB_BASE_URL}|" \
    -e "s|<boot-storage-account-name>|${BOOTSTRAP_STORAGE_ACCOUNT}|" \
    -e "s|<boot-storage-account-key>|${BOOTSTRAP_STORAGE_ACCOUNT_KEY}|" \
    -e "s|<boot-storage-account-sas>|${ESCAPED_BOOTSTRAP_STORAGE_SAS_TOKEN}|" \
    -e "s|<custom-image-uri>|${CUSTOM_IMAGE_URI}|" \
    -e "s|<consul-tenant-id>|${CONSUL_TENANT_ID}|" \
    -e "s|<consul-client-id>|${CONSUL_CLIENT_ID}|" \
    -e "s|<consul-client-key>|${CONSUL_CLIENT_KEY}|" \
    input.parameters.tfvars 
    # initialize terraform
    terraform init
    # apply configuration
    terraform apply -var-file=input.parameters.tfvars -auto-approve &> ${LOG_DIR}/main.tf.apply.log
    # all done
    display_progress "Main deployment completed"
    MAIN_OUTPUT=$(terraform output -json)
    # read and parse outputs
    SERVICES_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.services_id.value')
    SERVICES_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.services_principal_id.value')
    STATUS_TOPIC_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.status_topic_id.value')
    STORAGE_ACCOUNT_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.storage_account_id.value')
    KEY_VAULT_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.key_vault_id.value')
    KEY_VAULT_URI=$(echo "${MAIN_OUTPUT}" | jq -r '.key_vault_uri.value')

    API_LB_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.api_lb_id.value')
    API_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.api_vmss_id.value')
    API_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.api_vmss_principal_id.value')
    API_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.api_vmss_autoscale_id.value')

    COREDB_LB_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.coredb_lb_id.value')
    COREDB_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.coredb_vmss_id.value')
    COREDB_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.coredb_vmss_principal_id.value')
    COREDB_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.coredb_vmss_autoscale_id.value')

    MDS_LB_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.mds_lb_id.value')
    MDS_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.mds_vmss_id.value')
    MDS_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.mds_vmss_principal_id.value')
    MDS_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.mds_vmss_autoscale_id.value')

    CONSUL_VMSS_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.consul_vmss_id.value')
    CONSUL_VMSS_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.consul_vmss_principal_id.value')
    CONSUL_VMSS_AUTOSCALE_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.consul_vmss_autoscale_id.value')

    # leave
    popd
fi

# set roles
display_progress "Setting role assignments"
# az role assignment create --assignee-object-id ${SERVICES_PRINCIPAL_ID} --scope ${STORAGE_ACCOUNT_ID} --role Contributor
az role assignment create --assignee-object-id ${SERVICES_PRINCIPAL_ID} --resource-group ${RESOURCE_GROUP} --role Contributor

az role assignment create --assignee-object-id ${API_VMSS_PRINCIPAL_ID} --scope ${STATUS_TOPIC_ID} --role Contributor
az role assignment create --assignee-object-id ${API_VMSS_PRINCIPAL_ID} --scope ${KEY_VAULT_ID} --role Contributor
az role assignment create --assignee-object-id ${API_VMSS_PRINCIPAL_ID} --scope ${STORAGE_ACCOUNT_ID} --role Contributor

az role assignment create --assignee-object-id ${COREDB_VMSS_PRINCIPAL_ID} --scope ${STATUS_TOPIC_ID} --role Contributor
az role assignment create --assignee-object-id ${COREDB_VMSS_PRINCIPAL_ID} --scope ${KEY_VAULT_ID} --role Contributor
az role assignment create --assignee-object-id ${COREDB_VMSS_PRINCIPAL_ID} --scope ${STORAGE_ACCOUNT_ID} --role Contributor

az role assignment create --assignee-object-id ${MDS_VMSS_PRINCIPAL_ID} --scope ${STATUS_TOPIC_ID} --role Contributor
az role assignment create --assignee-object-id ${MDS_VMSS_PRINCIPAL_ID} --scope ${KEY_VAULT_ID} --role Contributor
az role assignment create --assignee-object-id ${MDS_VMSS_PRINCIPAL_ID} --scope ${STORAGE_ACCOUNT_ID} --role Contributor

az role assignment create --assignee-object-id ${CONSUL_VMSS_PRINCIPAL_ID} --scope ${STATUS_TOPIC_ID} --role Contributor
az role assignment create --assignee-object-id ${CONSUL_VMSS_PRINCIPAL_ID} --scope ${KEY_VAULT_ID} --role Contributor
az role assignment create --assignee-object-id ${CONSUL_VMSS_PRINCIPAL_ID} --scope ${STORAGE_ACCOUNT_ID} --role Contributor

az role assignment create --assignee-object-id ${SERVICES_PRINCIPAL_ID} --scope ${API_VMSS_ID} --role Contributor
az role assignment create --assignee-object-id ${SERVICES_PRINCIPAL_ID} --scope ${API_VMSS_AUTOSCALE_ID} --role Contributor

# scaling host
display_progress "Scaling consul"
az monitor autoscale update --ids ${CONSUL_VMSS_AUTOSCALE_ID} --count 3
az vmss scale --new-capacity 3 --no-wait --ids ${CONSUL_VMSS_ID}

display_progress "Scaling api"
az monitor autoscale update --ids ${API_VMSS_AUTOSCALE_ID} --count 2
az vmss scale --new-capacity 2 --no-wait --ids ${API_VMSS_ID}

display_progress "Scaling coredb"
az monitor autoscale update --ids ${COREDB_VMSS_AUTOSCALE_ID} --count 2
az vmss scale --new-capacity 2 --no-wait --ids ${COREDB_VMSS_ID}

display_progress "Scaling mds"
az monitor autoscale update --ids ${MDS_VMSS_AUTOSCALE_ID} --count 2
az vmss scale --new-capacity 2 --no-wait --ids ${COREDB_VMSS_ID}

# add to current list to be monitored
display_progress "Enabling key vault for services"
az webapp config appsettings set --settings KEY_VAULT_URI=${KEY_VAULT_URI} --ids ${SERVICES_ID}

# modules to publish
display_progress "Publishing modules"
MODULES=("services" ${SERVICES_ID})

# go over each function app
for ((i = 0; i < ${#MODULES[@]}; i+=2)); do
    # publishing services
    pusha ../scripts/${MODULES[$i]}
    # publish services
    display_progress "Publishing ${MODULES[$i]}"
    # publish
    ./publish.sh ${MODULES[$i+1]} &> ${LOG_DIR}/${MODULES[$i]}.publish.log 
    # cleanup
    popa
done

# register listeners
display_progress "Registering listeners"
./register-listeners.sh ${SERVICES_ID} ${STATUS_TOPIC_ID}

# add to current list to be monitored
STATUS_TARGETS=$(
	cat <<EOF
[{
    "name": "api",
    "type": "VirtualMachineScaleSet",
    "grace": 0,
    "minimum": 2,
    "expiration": 300,
    "unhealthy" : "DOWN",
    "resources": [
        "${API_VMSS_ID}"
    ]
},{
    "name": "coredb",
    "type": "VirtualMachineScaleSet",
    "grace": 0,
    "minimum": 2,
    "expiration": 300,
    "unhealthy" : "DOWN",
    "resources": [
        "${COREDB_VMSS_ID}"
    ]
}]
EOF
)

# update config
display_progress "Updating status targets"
az webapp config appsettings set --settings STATUS_TARGETS="${STATUS_TARGETS}" --ids ${SERVICES_ID}

# all done
display_progress "Deployment completed"
