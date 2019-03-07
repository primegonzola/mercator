#!/bin/bash
PROJECT_NAME="<PROJECT_NAME>"
ROOT_DIR="<ROOT_DIR>"
HOST_TYPE="<HOST_TYPE>"
HOST_ROLE="<HOST_ROLE>"
HOST_ID="<HOST_ID>"
STATUS_TOPIC_ID="<STATUS_TOPIC_ID>"
STORAGE_ACCOUNT_ID="<STORAGE_ACCOUNT_ID>"
KEYVAULT_ID="<KEYVAULT_ID>"

# check if running api host
if [[ "${HOST_ROLE}" == "api" || "${HOST_ROLE}" == "coredb" ]]; then
    # init status
    echo "init status"
    . ${ROOT_DIR}/host/init-status.sh
fi
# check if running api host
if [[ "${HOST_ROLE}" == "api" ]]; then
    # init api
    echo "init api"
    . ${ROOT_DIR}/host/init-api.sh
fi
# check if running coredb host
if [[ "${HOST_ROLE}" == "coredb" ]]; then
    # init coredb
    echo "init coredb"
    . ${ROOT_DIR}/host/init-coredb.sh
fi
