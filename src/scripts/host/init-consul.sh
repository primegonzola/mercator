#!/bin/bash

# install additional networking tools
apt-get -y install dnsutils ntp
# start and enable ntp service
systemctl daemon-reload
systemctl enable --now ntp.service

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

# Disable reverse dns lookup in SSH"
sh -c 'echo "\nUseDNS no" >> /etc/ssh/sshd_config'

# add group && user
addgroup \
    --system "consul"
# add user
adduser \
    --system \
    --disabled-login \
    --ingroup "consul" \
    --home "/srv/consul" \
    --no-create-home \
    --gecos "Consul" \
    --shell /bin/false \
    "consul"

# setup consul (could move to custom image creation)
chmod 0755 /usr/local/bin/consul
chown consul:consul /usr/local/bin/consul
mkdir -pm 0755 /etc/consul.d
mkdir -pm 0755 /opt/consul/data
chown consul:consul /opt/consul/data

# Installing dnsmasq
apt-get -y install dnsmasq-base dnsmasq
# Configuring dnsmasq to forward .consul requests to consul port 8600
sh -c 'echo "server=/consul/127.0.0.1#8600" >> /etc/dnsmasq.d/consul'
# enable service 
systemctl daemon-reload
systemctl enable --now dnsmasq.service

# default 
CONSUL_TAG=
CONSUL_TENANT_ID=
CONSUL_CLIENT_ID=
CONSUL_CLIENT_KEY=
CONSUL_SUBSCRIPTION_ID=

# get local ipv4
IP_ADDRESS="$(echo -e `hostname -I` | tr -d '[:space:]')"

# write config
CONSUL_DEFAULT_CONFIG_FILE=/etc/consul.d/consul-default.json
cat <<-EOF > ${CONSUL_DEFAULT_CONFIG_FILE}
{
  "advertise_addr": "${IP_ADDRESS}",
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "ui": true,
  "retry_join": ["provider=azure tag_name=consul_datacenter tag_value=${CONSUL_TAG} subscription_id=${CONSUL_SUBSCRIPTION_ID} tenant_id=${CONSUL_TENANT_ID} client_id=${CONSUL_CLIENT_ID} secret_access_key=${CONSUL_CLIENT_KEY}"]
}
EOF

# create consul service
CONSUL_SERVICE_FILE=/etc/systemd/system/consul.service
cat <<-EOF > ${CONSUL_SERVICE_FILE}
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -config-dir /etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=consul
Group=consul

[Install]
WantedBy=multi-user.target
EOF

# enable consul service
systemctl daemon-reload
systemctl enable --now consul.service

