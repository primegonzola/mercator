#!/bin/bash
. ./utils.sh

# tools required to be able to work
require_tool az || exit 1
require_tool jq || exit 1
# require_tool mvn || exit 1
require_tool npm || exit 1
require_tool node || exit 1
# require_tool java || exit 1
require_tool packer || exit 1
require_tool terraform || exit 1
require_tool dos2unix || exit 1

function display_help() {
	echo -e "\n${PROJECT_NAME} deployment utility v1.0\n"
	echo -e "usage: deploy.sh -/-- options:\n"
	echo -e "\t--help, -h"
	echo -e "\t  displays more detailed help\n"
	echo -e "\t--resource-group, -g <resource group>"
	echo -e "\t  the resource group to deploy to\n"
	echo -e "\t--location, -l <location> "
	echo -e "\t  the location to deploy to\n"
	echo -e "\t--tenant-id, -t <tenant id>"
	echo -e "\t  the tenant id to use for deploying\n"
	echo -e "\t--subscription-id, -s <subscription id>"
	echo -e "\t  the subscription id to use for deploying\n"
	echo -e "\t--service-principal-id, -u <service principal id>"
	echo -e "\t  the service principal id to use for deploying\n"
	echo -e "\t--service-principal-key, -p <service principal key>"
	echo -e "\t  the service principal key to use for deploying\n"
	echo -e "\t--custom-image-uri, -ciu <custom-image-uri>"
	echo -e "\t  the custom base image to use to install application upon \n"
	echo -e "\t--name-fix, -n <name fix>"
	echo -e "\t  post fix to use for naming different resources\n"
	echo -e "\t--name-fix-resource-group, -ng"
	echo -e "\t  apply same name fix to resource group\n"
	echo -e "\t--verbose, -v"
	echo -e "\t  verbose mode outputting more details\n"
	echo -e "\t--development, -dev"
	echo -e "\t  development mode taking some shortcuts\n"
	echo -e "\t--deployment-model, -dm [arm | tf]\n"
	echo -e "\t  the deployment model to use arm or terraform \n"
}

# set some defaults
BUILD_MODE="default"
PROJECT_NAME="mercator"
OPERATION_MODE="default"
DEPLOYMENT_MODEL="arm"
CUSTOM_IMAGE_URI="none"

# parse the argumens
while true; do
  case "$1" in
		-h | --help ) display_help; exit 1 ;;
    -l | --location ) LOCATION="$2"; shift ; shift ;;
    -g | --resource-group ) RESOURCE_GROUP="$2"; shift ; shift ;;
    -t | --tenant-id ) TENANT_ID="$2"; shift ; shift ;;
    -s | --subscription-id ) SUBSCRIPTION_ID="$2"; shift ; shift ;;
    -u | --service-principal-id ) SERVICE_PRINCIPAL_ID="$2"; shift ; shift ;;
    -p | --service-principal-key ) SERVICE_PRINCIPAL_KEY="$2"; shift ; shift ;;
    -n | --name-fix ) NAME_FIX="$2"; shift ; shift ;;
    -ng | --name-fix-resource-group ) NAME_FIX_RESOURCE_GROUP=true; shift ;;
    -v | --verbose ) BUILD_MODE="verbose"; shift ; shift ;;
    -dev | --development ) OPERATION_MODE="development"; shift ;;
    -dm | --deployment-model ) DEPLOYMENT_MODEL="$2"; shift ; shift ;;
    -ciu | --custom-image-uri ) CUSTOM_IMAGE_URI="$2"; shift ; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# validation checking
if [ -z ${LOCATION+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --location, -l is missing.\n"
	echo -e "\tusage: --location, -l [westeurope, westus, northeurope, ...]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${RESOURCE_GROUP+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --resource-group, -g is missing.\n"
	echo -e "\tusage: --resource-group, -g [NAME]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-id, -u is missing.\n"
	echo -e "\tusage: --service-principal-id, -u [SERVICE PRINCIPAL ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_KEY+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-key, -p is missing.\n"
	echo -e "\tusage: --service-principal-key, -p [SERVICE PRINCIPAL KEY]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${TENANT_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --tenant-id, -s is missing.\n"
	echo -e "\tusage: --tenant-id, -p [TENANT ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SUBSCRIPTION_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --subscription-id, -s is missing.\n"
	echo -e "\tusage: --subscription-id, -p [SUBSCRIPTION ID]"
	echo -e "\n"
	exit 1; 
fi

if [ -n "${NAME_FIX+set}" ]; then
	UNIQUE_NAME_FIX=${NAME_FIX} 
else 
	UNIQUE_NAME_FIX="$(dd if=/dev/urandom bs=6 count=1 2>/dev/null | base64 | tr '[:upper:]+/=' '[:lower:]abc')"
fi
if [ -n "${NAME_FIX_RESOURCE_GROUP+set}" ]; then
	RESOURCE_GROUP=${RESOURCE_GROUP}-${UNIQUE_NAME_FIX} 		
fi

# entering deployment environment
display_progress "Preparing deployment environment"
# variables come here
OUTPUT_DIR="$(dirname "$PWD")"/output

# prepare target environment
rm -rf ${OUTPUT_DIR} >/dev/null

# prepare deploy dire
mkdir -p ${OUTPUT_DIR}/deploy >/dev/null
cp -r * ${OUTPUT_DIR}/deploy >/dev/null

# prepare scripts dir
mkdir -p ${OUTPUT_DIR}/scripts >/dev/null
pushd ../scripts >/dev/null
tar cf - --exclude=node_modules . | (cd ${OUTPUT_DIR}/scripts && tar xvf - ) >/dev/null
popd >/dev/null

# prepare log dir
LOG_DIR=${OUTPUT_DIR}/logs
mkdir -p ${LOG_DIR} >/dev/null

# all done change directory and let's boot
pushd ${OUTPUT_DIR}/deploy >/dev/null

# assure proper format
dos2unix -q ${OUTPUT_DIR}/deploy/*.*

# entering deployment environment
display_progress "Entering deployment environment"

# create a different config file for azure cli so no conflict with existing user profile
export AZURE_CONFIG_DIR=${OUTPUT_DIR}/deploy/azure-configure

# do explicit login
az login --service-principal -t ${TENANT_ID} -u ${SERVICE_PRINCIPAL_ID} -p ${SERVICE_PRINCIPAL_KEY} 

# select specified subscription
az account set --subscription ${SUBSCRIPTION_ID}

# extract principal object id
SERVICE_PRINCIPAL_OID=$(az ad sp show --id ${SERVICE_PRINCIPAL_ID} | jq -r '.objectId')

# pass the environment
cat <<-EOF > ${OUTPUT_DIR}/deploy/environment.sh
LOCATION="${LOCATION}"
OUTPUT_DIR="${OUTPUT_DIR}"
LOG_DIR="${LOG_DIR}"
BUILD_MODE="${BUILD_MODE}"
PROJECT_NAME="${PROJECT_NAME}"
DEPLOYMENT_MODEL="${DEPLOYMENT_MODEL}"
RESOURCE_GROUP="${RESOURCE_GROUP}"
TENANT_ID="${TENANT_ID}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
OPERATION_MODE="${OPERATION_MODE}"
UNIQUE_NAME_FIX="${UNIQUE_NAME_FIX}"
SERVICE_PRINCIPAL_ID="${SERVICE_PRINCIPAL_ID}"
SERVICE_PRINCIPAL_KEY="${SERVICE_PRINCIPAL_KEY}"
SERVICE_PRINCIPAL_OID="${SERVICE_PRINCIPAL_OID}"
CUSTOM_IMAGE_URI="${CUSTOM_IMAGE_URI}"
EOF

# boot system
${OUTPUT_DIR}/deploy/boot.sh
# entering deployment environment
display_progress "Leaving deployment environment"
# do explicit login
az logout
# clean up
popd >/dev/null

