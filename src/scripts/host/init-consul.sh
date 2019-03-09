#!/bin/bash
CONSUL_MODE=${1}
CONSUL_VMSS_ID="${2}"
CONSUL_TENANT_ID="${3}"
CONSUL_CLIENT_ID="${4}"
CONSUL_CLIENT_KEY="${5}"

# extract info
PARTS=(${CONSUL_VMSS_ID//// })
CONSUL_VMSS_NAME=${PARTS[7]}
CONSUL_RESOURCE_GROUP=${PARTS[3]}
CONSUL_SUBSCRIPTION_ID=${PARTS[1]}

# run consul as server
/opt/consul/bin/run-consul \
    --${CONSUL_MODE} \
    --scale-set-name "${CONSUL_VMSS_NAME}" \
    --subscription-id "${CONSUL_SUBSCRIPTION_ID}" \
    --tenant-id "${CONSUL_TENANT_ID}" \
    --client-id "${CONSUL_CLIENT_ID}" \
    --secret-access-key "${CONSUL_CLIENT_KEY}"
