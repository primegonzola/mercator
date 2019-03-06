#!/bin/bash

# resolve most of data required
PARTS=(${STATUS_TOPIC_ID//// })
SUBSCRIPTION_ID=${PARTS[1]}
RESOURCE_GROUP=${PARTS[3]}
STATUS_TOPIC_NAME=${PARTS[7]}

HOST_STATUS="UP"
HOST_NAME=$(hostname)
HOST_IP_ADDRESS=$(hostname --ip-address)
#HOST_IP_ADDRESS=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')

# use MSI to get access token
ACCESS_TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true | jq -r .access_token)

# get topic key and endpoint
REQUEST_URI=https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.EventGrid/topics/${STATUS_TOPIC_NAME}/listKeys?api-version=2018-01-01
STATUS_TOPIC_KEY=$(curl --silent -X POST -d "" -s --header "authorization: Bearer ${ACCESS_TOKEN}" ${REQUEST_URI} | jq -r .key1)
REQUEST_URI=https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.EventGrid/topics/${STATUS_TOPIC_NAME}?api-version=2018-01-01
STATUS_TOPIC_ENDPOINT=$(curl --silent -X GET -s --header "authorization: Bearer ${ACCESS_TOKEN}" ${REQUEST_URI} | jq -r .properties.endpoint)

# prepare our event data
STATUS_EVENT_DATA=$(
	cat <<EOF
{
    "id": "$RANDOM",
    "eventType": "mercator-status",
    "subject": "${HOST_ID}",
    "eventTime": "$(date +%Y-%m-%dT%H:%M:%S%z)",
    "data": {
        "type": "${HOST_TYPE}",
        "category": "${HOST_ROLE}",
        "name": "${HOST_NAME}",
        "status": "${HOST_STATUS}",
        "data": {
            "ipAddress": "${HOST_IP_ADDRESS}"
        } 
    }
}
EOF
)

# post it to the grid
curl -X POST -H "aeg-sas-key: ${STATUS_TOPIC_KEY}" -d "[${STATUS_EVENT_DATA}]" ${STATUS_TOPIC_ENDPOINT}

# check result code
if [ $? -ne 0 ]; then
	echo >&2 "error sending status heartbeat"
	exit $?
fi
