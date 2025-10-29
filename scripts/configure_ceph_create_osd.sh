#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_create_osd.sh <osd_idx>"
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

##### configure ceph #####

function create_osd()
{
    # 创建 OSD 所在的目录
    mkdir -p ${osd_data_path}

    ceph-volume lvm prepare --data /dev/${nvme_dev}p1 --block.db /dev/${nvme_dev}p2 --block.wal /dev/${nvme_dev}p3

    ceph-osd -i ${osd_idx}
}

create_osd
