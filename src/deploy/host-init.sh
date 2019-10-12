#!/bin/bash
PROJECT_NAME="${1}"
BOOTSTRAP_STORAGE_ACCOUNT_NAME="${2}"
BOOTSTRAP_STORAGE_ACCOUNT_KEY="${3}"
BOOTSTRAP_STORAGE_ACCOUNT_SAS="${4}"
HOST_TYPE="${5}"
HOST_ID="${6}"
HOST_ROLE="${7}"
STATUS_TOPIC_ID="${8}"
STORAGE_ACCOUNT_ID="${9}"
KEYVAULT_ID="${10}"
CONSUL_VMSS_ID="${11}"
CONSUL_TENANT_ID="${12}"
CONSUL_CLIENT_ID="${13}"
CONSUL_CLIENT_KEY="${14}"

# define root of all evil
ROOT_DIR=/opt/${PROJECT_NAME}

# create working folders
mkdir -vp ${ROOT_DIR}

cat <<-EOF >${ROOT_DIR}/sanity-check.sh
ls -la /etc/systemd/system
cat /var/log/waagent.log
cat /var/lib/waagent/custom-script/download/0/stderr
cat /var/lib/waagent/custom-script/download/0/stdout
cat /var/lib/waagent/custom-script/download/1/stderr
cat /var/lib/waagent/custom-script/download/1/stdout
EOF
# right permissions
chmod +x ${ROOT_DIR}/sanity-check.sh
# create working folders
mkdir -vp ${ROOT_DIR}/host
# download
./download.sh ${BOOTSTRAP_STORAGE_ACCOUNT_NAME} ${BOOTSTRAP_STORAGE_ACCOUNT_KEY} bootstrap host.tar.gz ${ROOT_DIR}/host/host.tar.gz
# change dir to host
pushd ${ROOT_DIR}/host
# untar file
tar -xzvf host.tar.gz
# clean up
rm -rf host.tar.gz
# set permissions for all scripts
chmod +x ${ROOT_DIR}/host/*.sh
# restore dir
popd
# replace in target init file 
sed --in-place=.bak \
	-e "s|<PROJECT_NAME>|${PROJECT_NAME}|" \
	-e "s|<BOOTSTRAP_STORAGE_ACCOUNT_NAME>|${BOOTSTRAP_STORAGE_ACCOUNT_NAME}|" \
	-e "s|<BOOTSTRAP_STORAGE_ACCOUNT_KEY>|${BOOTSTRAP_STORAGE_ACCOUNT_KEY}|" \
	-e "s|<BOOTSTRAP_STORAGE_ACCOUNT_SAS>|${BOOTSTRAP_STORAGE_ACCOUNT_SAS}|" \
	-e "s|<ROOT_DIR>|${ROOT_DIR}|" \
	-e "s|<HOST_TYPE>|${HOST_TYPE}|" \
	-e "s|<HOST_ID>|${HOST_ID}|" \
	-e "s|<HOST_ROLE>|${HOST_ROLE}|" \
	-e "s|<STATUS_TOPIC_ID>|${STATUS_TOPIC_ID}|" \
	-e "s|<STORAGE_ACCOUNT_ID>|${STORAGE_ACCOUNT_ID}|" \
	-e "s|<KEYVAULT_ID>|${KEYVAULT_ID}|" \
	-e "s|<CONSUL_VMSS_ID>|${CONSUL_VMSS_ID}|" \
	-e "s|<CONSUL_TENANT_ID>|${CONSUL_TENANT_ID}|" \
	-e "s|<CONSUL_CLIENT_ID>|${CONSUL_CLIENT_ID}|" \
	-e "s|<CONSUL_CLIENT_KEY>|${CONSUL_CLIENT_KEY}|" \
	${ROOT_DIR}/host/process.sh

# execute directly the init
${ROOT_DIR}/host/process.sh "init"
