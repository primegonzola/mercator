#!/bin/bash

# constants come here
HOST_NAME=$(hostname)
SCHEDULED_EVENTS_API_URI=http://169.254.169.254/metadata/scheduledevents?api-version=2019-01-01
# get the meta data 
META_DATA=$(curl -X GET -H "Metadata:true" ${SCHEDULED_EVENTS_API_URI})
# get events
META_DATA=$(cat ./meta-data.json)
META_DATA_EVENTS=$(echo ${META_DATA} | jq -r '.Events')
META_DATA_EVENTS_LENGTH=$(echo ${META_DATA} | jq -r '.Events | length')

# loop over events
for ((index=0;index<${META_DATA_EVENTS_LENGTH};index++)); do
    EVENT_DATA=$(echo $META_DATA_EVENTS | jq --arg index $index '.[$index|tonumber]')
    # get event data
    EVENT_ID=$(echo ${EVENT_DATA} | jq -r '.EventId')
    EVENT_TYPE=$(echo ${EVENT_DATA} | jq -r '.EventType')
    EVENT_STATUS=$(echo ${EVENT_DATA} | jq -r '.EventStatus')
    EVENT_RESOURCES=$(echo ${EVENT_DATA} | jq -r '.Resources')
    EVENT_RESOURCES_LENGTH=$(echo ${EVENT_DATA} | jq -r '.Resources | length')
    
    # check if termination event
    if [[ "${EVENT_TYPE}" == "Terminate" ]]; then
        for ((rindex=0;rindex<${EVENT_RESOURCES_LENGTH};rindex++)); do
            # get the resource
            EVENT_RESOURCE=$(echo $EVENT_RESOURCES | jq --arg rindex $rindex '.[$rindex|tonumber]')
            # check if this machine
            if [[ "${EVENT_RESOURCE}" == "${HOST_NAME}" ]]; then
    
                # notify downstream 
                echo "processing termination ${HOST_ROLE}"
                . ${ROOT_DIR}/host/process.sh "terminate"

                # all done notify completion
EVENT_START_REQUEST=$(
	cat <<EOF
{
	"StartRequests" : [
		{
			"EventId": "${EVENT_ID}"
		}
	]
}
EOF
)
            fi
        done

        # mark operation as completed to accelerate shutdown etc
        curl -X POST -d "${EVENT_START_REQUEST}" -H "Metadata:true" ${SCHEDULED_EVENTS_API_URI}
    fi
done
