#!/bin/bash
ACTION=${1}
PROJECT_NAME="<PROJECT_NAME>"
ROOT_DIR="<ROOT_DIR>"
HOST_TYPE="<HOST_TYPE>"
HOST_ROLE="<HOST_ROLE>"
HOST_ID="<HOST_ID>"
STATUS_TOPIC_ID="<STATUS_TOPIC_ID>"
STORAGE_ACCOUNT_ID="<STORAGE_ACCOUNT_ID>"
KEYVAULT_ID="<KEYVAULT_ID>"
CONSUL_VMSS_ID="<CONSUL_VMSS_ID>"
CONSUL_TENANT_ID="<CONSUL_TENANT_ID>"
CONSUL_CLIENT_ID="<CONSUL_CLIENT_ID>"
CONSUL_CLIENT_KEY="<CONSUL_CLIENT_KEY>"
DATA_IMAGE_URI="<DATA_IMAGE_URI>"

# check if running api host
if [[ "${HOST_ROLE}" == "api" || "${HOST_ROLE}" == "coredb" || "${HOST_ROLE}" == "mds" ]]; then
    # process status
    echo "process status"
    . ${ROOT_DIR}/host/process-status.sh "${ACTION}"
    # process consul
    echo "process consul client"
    . ${ROOT_DIR}/host/process-consul.sh "${ACTION}" "client" ${CONSUL_VMSS_ID} ${CONSUL_TENANT_ID} ${CONSUL_CLIENT_ID} ${CONSUL_CLIENT_KEY}
fi

# check if running CONSUL host
if [[ "${HOST_ROLE}" == "consul" ]]; then
    # process consul
    echo "process consul client"
    . ${ROOT_DIR}/host/process-consul.sh "${ACTION}" "server" ${CONSUL_VMSS_ID} ${CONSUL_TENANT_ID} ${CONSUL_CLIENT_ID} ${CONSUL_CLIENT_KEY}
fi
# check if running api host
if [[ "${HOST_ROLE}" == "api" ]]; then
    # process api
    echo "process api"
    . ${ROOT_DIR}/host/process-api.sh "${ACTION}"
fi
# check if running coredb host
if [[ "${HOST_ROLE}" == "coredb" ]]; then
    # process coredb
    echo "process coredb"
    . ${ROOT_DIR}/host/process-coredb.sh "${ACTION}"
fi
# check if running mds host
if [[ "${HOST_ROLE}" == "mds" ]]; then
    # process mds
    echo "process mds"
    . ${ROOT_DIR}/host/process-mds.sh "${ACTION}"
fi
