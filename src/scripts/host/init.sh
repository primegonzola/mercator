#!/bin/bash
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

# check if running api host
if [[ "${HOST_ROLE}" == "api" || "${HOST_ROLE}" == "coredb" || "${HOST_ROLE}" == "mds" ]]; then
    # init status
    echo "init status"
    . ${ROOT_DIR}/host/init-status.sh
    echo "init consul client"
    . ${ROOT_DIR}/host/init-consul.sh "client" ${CONSUL_VMSS_ID} ${CONSUL_TENANT_ID} ${CONSUL_CLIENT_ID} ${CONSUL_CLIENT_KEY}
fi
# check if running CONSUL host
if [[ "${HOST_ROLE}" == "consul" ]]; then
    # init consul
    echo "init consul cluster"
    . ${ROOT_DIR}/host/init-consul.sh "server" ${CONSUL_VMSS_ID} ${CONSUL_TENANT_ID} ${CONSUL_CLIENT_ID} ${CONSUL_CLIENT_KEY}
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
# check if running mds host
if [[ "${HOST_ROLE}" == "mds" ]]; then
    # init mds
    echo "init mds"
    . ${ROOT_DIR}/host/init-mds.sh
fi

