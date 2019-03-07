#!/bin/bash

# install azure cli
# Install prerequisite packages
apt-get -y install apt-transport-https lsb-release software-properties-common dirmngr
# Modify your sources list
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
# Get the Microsoft signing key
apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
--keyserver packages.microsoft.com \
--recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF
# install cli
apt-get -y update
apt-get -y install azure-cli    

# get consul related artifacts
git clone https://github.com/hashicorp/terraform-azurerm-consul.git /tmp/terraform-azurerm-consul

# install consul
/tmp/terraform-azurerm-consul/modules/install-consul/install-consul --version 1.4.3

# install dnsmasq
/tmp/terraform-azurerm-consul/modules/install-dnsmasq/install-dnsmasq

# run consul
# /opt/consul/bin/run-consul --server
