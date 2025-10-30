#!/usr/bin/env bash

# Run this script on client machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./resize_rbd_image.sh <new_size>"
    echo "      new_size:       e.g. '250G'"
    echo "**** Run this script on client machine! ****"
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

osd_idx=$1

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### resize rbd image #####

cd ${ceph_bin_path}
./rbd resize ${rbd_pool_name}/${rbd_image_name} --size ${new_size}
./rbd disk-usage -p ${rbd_pool_name}

xfs_growfs ${rbd_dev_mount_point}
