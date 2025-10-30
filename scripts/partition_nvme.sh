#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./partition_nvme.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

# TODO: 根据大小占比计算百分比
function partition_nvme()
{
    yum install -y nvme-cli
    nvme format -s 1 -f /dev/${nvme_dev}

    parted -s /dev/${nvme_dev} mklabel gpt \
      && parted -s /dev/${nvme_dev} mkpart primary 0% 33% \
      && parted -s /dev/${nvme_dev} mkpart primary 33% 66% \
      && parted -s /dev/${nvme_dev} mkpart primary 66% 100%
}

partition_nvme
