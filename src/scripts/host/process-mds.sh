#!/bin/bash
ACTION=${1}

# from https://msftstack.wordpress.com/2017/05/10/figuring-out-azure-vm-scale-set-machine-names/
function hostname_to_vmid()
{
    VMSS_HOST_NAME=${1}
    # get last 6 characters and remove leading zeroes, reverse
    HEXATRIG=${VMSS_HOST_NAME: -6}
    HEXATRIG=$(echo "${HEXATRIG#"${HEXATRIG%%[!0]*}"}")
    HEXATRIG=$(echo ${HEXATRIG}| rev)
    VMID=0
    MULTIPLIER=1
    for (( i=0; i<${#HEXATRIG}; i++ )); do
        CHARACTER=${HEXATRIG:$i:1}
        re='^[0-9]+$'
        if ! [[ ${CHARACTER} =~ $re ]] ; then
            ORD=$(LC_CTYPE=C printf '%d' "'${CHARACTER}")
            ADD=$((${ORD} - 55))
            ADD=$((${ADD} * ${MULTIPLIER}))
            VMID=$((${VMID} + ${ADD}))
        else
            ADD=$((${CHARACTER} * ${MULTIPLIER}))
            VMID=$((${VMID} + ${ADD}))
        fi
        MULTIPLIER=$((${MULTIPLIER} * 36))
    done
    echo ${VMID}
}


# extract usefull info for later on
HOST_NAME=$(hostname)
PARTS=(${HOST_ID//// })
MDS_VMSS_NAME=${PARTS[7]}
MDS_RESOURCE_GROUP=${PARTS[3]}
MDS_SUBSCRIPTION_ID=${PARTS[1]}
MDS_DISK_0_NAME=mds-${HOST_NAME}-0-dsk

# check if running init
if [[ "${ACTION}" == "init" ]]; then
    # login using access token from msi
    az login --identity

    # create the disk
    az disk create -n ${MDS_DISK_0_NAME} -g ${MDS_RESOURCE_GROUP} --source ${DATA_IMAGE_URI}

    # resolve instance id
    VMSS_VM_INSTANCE_ID=$(hostname_to_vmid ${HOST_NAME})

    # attach disk to lun 0
    az vmss disk attach --resource-group ${MDS_RESOURCE_GROUP} --vmss-name ${MDS_VMSS_NAME} --instance-id ${VMSS_VM_INSTANCE_ID} --disk ${MDS_DISK_0_NAME} --lun 0  

    # prep data dir
    mkdir /datadisk0

    # mount
    mount /dev/sdc1 /datadisk0

# check if terminating
elif [[ "${ACTION}" == "terminate" ]]; then
    # unmount
    umount /dev/sdc1

    # login using access token from msi
    az login --identity

    # detach disk
    az vmss disk detach --resource-group ${MDS_RESOURCE_GROUP} --vmss-name ${MDS_VMSS_NAME} --instance-id ${VMSS_VM_INSTANCE_ID} --lun 0  

    # delete the disk
    az disk delete -n ${MDS_DISK_0_NAME} -g ${MDS_RESOURCE_GROUP} -y
fi

