#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_create_mgr.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function create_mgr()
{
    cd ${ceph_bin_path}

    local hostname=`hostname`
    # 创建 manager 数据目录
    mkdir -p ${mgr_data_path}/ceph-${hostname}

    ./ceph auth get-or-create mgr.${hostname} mon 'allow *' osd 'allow *' mds 'allow *'
    ./ceph auth get mgr.${hostname} -o  /var/lib/ceph/mgr/ceph-${hostname}/keyring
    # 启动
    ./ceph-mgr -i ${hostname}
}

create_mgr
