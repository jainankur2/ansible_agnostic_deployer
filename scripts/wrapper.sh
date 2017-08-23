#!/bin/bash

# wapper script to agnostic_ansible_deployer playbooks

if [ $# != 2 ]; then
    echo "2 args needed" >&2
    echo
    echo 'wapper script to agnostic_ansible_deployer playbooks'
    echo "./$0 RCFILE ACTION"
    echo 'args'
    echo '- RCFILE: to be sourced, containing needed env variables (especially envtype_args array)'
    echo '- ACTION: provision|destroy|stop|start'
    exit 2
fi

set -xe -o pipefail

. "$1"

if [ -z "${GUID}" ]; then
    echo "GUID is mandatory"
    exit 2
fi

REGION=${REGION:-us-east-1}
KEYNAME=${KEYNAME:-ocpkey}
ENVTYPE=${ENVTYPE:-generic-example}
CLOUDPROVIDER=${CLOUDPROVIDER:-ec2}
if [ "$CLOUDPROVIDER" = "ec2" ]; then
    if [ -z "${HOSTZONEID}" ]; then
        echo "HOSTZONEID vars are mandatory"
        exit 2
    fi
fi

INSTALL_IPA_CLIENT=${INSTALL_IPA_CLIENT:-false}
REPO_METHOD=${REPO_METHOD:-file}
SOFTWARE_TO_DEPLOY=${SOFTWARE_TO_DEPLOY:-none}

STACK_NAME=${ENVTYPE}-${GUID}
ORIG=$(cd $(dirname $0); cd ..; pwd)
DEPLOYER_REPO_PATH="${ORIG}/ansible"

case $2 in
    provision)
        ansible-playbook \
            ${DEPLOYER_REPO_PATH}/main.yml  \
            -i ${DEPLOYER_REPO_PATH}/inventory/${CLOUDPROVIDER}.py \
            -e "ANSIBLE_REPO_PATH=${DEPLOYER_REPO_PATH}" \
            -e "guid=${GUID}" \
            -e "env_type=${ENVTYPE}" \
            -e "key_name=${KEYNAME}" \
            -e "cloud_provider=${CLOUDPROVIDER}" \
            -e "aws_region=${REGION}" \
            -e "HostedZoneId=${HOSTZONEID}" \
            -e "install_ipa_client=${INSTALL_IPA_CLIENT}" \
            -e "software_to_deploy=${SOFTWARE_TO_DEPLOY}" \
            -e "repo_method=${REPO_METHOD}" \
            ${ENVTYPE_ARGS[@]}
        ;;
    destroy)
        ansible-playbook \
            ${DEPLOYER_REPO_PATH}/configs/${ENVTYPE}/destroy_env.yml \
            -i ${DEPLOYER_REPO_PATH}/inventory/${CLOUDPROVIDER}.py \
            -e "ANSIBLE_REPO_PATH=${DEPLOYER_REPO_PATH}" \
            -e "guid=${GUID}" \
            -e "env_type=${ENVTYPE}"  \
            -e "cloud_provider=${CLOUDPROVIDER}" \
            -e "aws_region=${REGION}"  \
            -e "HostedZoneId=${HOSTZONEID}"  \
            -e "key_name=${KEYNAME}"  \
        ;;
    stop)
        aws ec2 stop-instances --region $REGION --instance-ids $(aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" --query Reservations[*].Instances[*].InstanceId --region $REGION --output text)
        ;;
    start)
        aws ec2 start-instances --region $REGION --instance-ids `aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" --query Reservations[*].Instances[*].InstanceId --region $REGION --output text`
        ;;
esac