#!/bin/bash
. ./utils.sh
# parse arguments
IMAGE_NAME="${1}"
STORAGE_ACCOUNT="${2}"
TENANT_ID="${3}"
SERVICE_PRINCIPAL_ID="${4}"
SERVICE_PRINCIPAL_KEY="${5}"
SUBSCRIPTION_ID="${6}"
RESOURCE_GROUP="${7}"
LOCATION="${8}"

display_progress "Building custom image"
# prepare environment
export ARM_TENANT_ID=${TENANT_ID}
export ARM_CLIENT_ID=${SERVICE_PRINCIPAL_ID}
export ARM_CLIENT_SECRET=${SERVICE_PRINCIPAL_KEY}
export ARM_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
export ARM_RESOURCE_GROUP=${RESOURCE_GROUP}
export ARM_LOCATION=${LOCATION}
export ARM_VM_SIZE="Standard_F1"
export ARM_SSH_USER="mercator" 
export ARM_SSH_PASS="Dummy2PassWord!"
export ARM_IMAGE_NAME=${IMAGE_NAME}
export ARM_STORAGE_ACCOUNT=${STORAGE_ACCOUNT}
# run packer
packer build -on-error=ask ./custom-image.json
# output the url 
echo "$(cat ./manifest.json | jq -r '.builds[0].artifact_id')"
