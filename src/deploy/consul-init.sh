#!/bin/bash
VMSS_ID="${1}"
CONSUL_TENANT_ID="${2}"
CONSUL_CLIENT_ID="${3}"
CONSUL_CLIENT_KEY="${4}"

# extract info
PARTS=(${VMSS_ID//// })
VMSS_NAME=${PARTS[7]}
RESOURCE_GROUP=${PARTS[3]}
SUBSCRIPTION_ID=${PARTS[1]}

# # install azure cli
# # Install prerequisite packages
# apt-get -y install apt-transport-https lsb-release software-properties-common dirmngr
# # Modify your sources list
# AZ_REPO=$(lsb_release -cs)
# echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
#     sudo tee /etc/apt/sources.list.d/azure-cli.list
# # Get the Microsoft signing key
# apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
#     --keyserver packages.microsoft.com \
#     --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF
# # install cli
# apt-get -y update
# apt-get -y install azure-cli    

# # get consul related artifacts
# git clone https://github.com/hashicorp/terraform-azurerm-consul.git /tmp/terraform-azurerm-consul

# # install consul
# /tmp/terraform-azurerm-consul/modules/install-consul/install-consul --version 1.4.3

# # install dnsmasq
# /tmp/terraform-azurerm-consul/modules/install-dnsmasq/install-dnsmasq

# run consul as server
/opt/consul/bin/run-consul \
    --server \
    --scale-set-name "${VMSS_NAME}" \
    --subscription-id "${SUBSCRIPTION_ID}" \
    --tenant-id "${CONSUL_TENANT_ID}" \
    --client-id "${CONSUL_CLIENT_ID}" \
    --secret-access-key "${CONSUL_CLIENT_KEY}"
