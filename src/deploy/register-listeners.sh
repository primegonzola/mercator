#!/bin/bash

# get our stuff
. ./utils.sh

SERVICES_ID="${1}"
STATUS_TOPIC_ID="${2}"

PARTS=(${SERVICES_ID//// })
RESOURCE_GROUP=${PARTS[3]}
SERVICES_NAME=${PARTS[7]}

PARTS=(${STATUS_TOPIC_ID//// })
STATUS_TOPIC_NAME=${PARTS[7]}

STATUS_TOPIC_RESOURCES_NAME=${STATUS_TOPIC_NAME}-resources
STATUS_TOPIC_SUBSCRIPTION_NAME=${STATUS_TOPIC_NAME}-subscription

# get our publishing profile
PUBLISHING_PROFILE_JSON=$(az webapp deployment list-publishing-profiles --output json --resource-group ${RESOURCE_GROUP} --name ${SERVICES_NAME})
PUBLISHING_USERNAME=$(echo ${PUBLISHING_PROFILE_JSON} | jq -r '.[0] | .userName')
PUBLISHING_PASSWORD=$(echo ${PUBLISHING_PROFILE_JSON} | jq -r '.[0] | .userPWD')
AUTH_BASE64_TOKEN=$(printf ${PUBLISHING_USERNAME}:${PUBLISHING_PASSWORD} | iconv -t WINDOWS-1252 | base64 --wrap=0)

# save configuration
STATUS_TOPIC_KEY=$(az eventgrid topic key list --name ${STATUS_TOPIC_NAME} -g ${RESOURCE_GROUP} --query "key1" --output tsv)
STATUS_TOPIC_ENDPOINT=$(az eventgrid topic show --name ${STATUS_TOPIC_NAME} -g ${RESOURCE_GROUP} --query "endpoint" --output tsv)

# proper uri's
KUDU_EXEC_CMD_URI="https://"${SERVICES_NAME}".scm.azurewebsites.net/api/functions/admin/masterkey"
SERVICES_MASTER_KEY=$(curl --silent --max-time 20 --header "Content-Type: application/json" --header "Authorization: Basic "${AUTH_BASE64_TOKEN} --request GET ${KUDU_EXEC_CMD_URI} | jq -r '.masterKey')

SERVICES_SYSTEM_KEY_URI="https://"${SERVICES_NAME}".azurewebsites.net/admin/host/systemkeys/eventgridextensionconfig_extension?code="${SERVICES_MASTER_KEY}
SERVICES_SYSTEM_KEY=$(curl --silent --max-time 20 --header "Content-Type: application/json" --header "Authorization: Basic "${AUTH_BASE64_TOKEN} --request GET ${SERVICES_SYSTEM_KEY_URI} | jq -r '.value')
SERVICES_TOPIC_ENDPOINT="https://"${SERVICES_NAME}".azurewebsites.net/admin/extensions/EventGridExtensionConfig?functionName=monitor-events&code="${SERVICES_SYSTEM_KEY}

# create listeners
display_progress "Registering status listener on subscription level"
az eventgrid event-subscription create --name ${STATUS_TOPIC_SUBSCRIPTION_NAME} --topic-name ${STATUS_TOPIC_NAME} --resource-group ${RESOURCE_GROUP} --endpoint ${SERVICES_TOPIC_ENDPOINT}

# we only handle events on subscription level
# display_progress "Registering status listener on resource group level"
# az eventgrid event-subscription create --name ${STATUS_TOPIC_RESOURCES_NAME} --resource-group ${RESOURCE_GROUP} --endpoint ${SERVICES_TOPIC_ENDPOINT}
