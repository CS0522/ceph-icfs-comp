#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_create_mon.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function create_mon()
{
    cd ${ceph_bin_path}

    local hostname=`hostname`
    # 创建 monitor 数据目录
    mkdir -p ${mon_data_path}/ceph-${hostname}

    # 用 monitor map 和 keyring 填充 monitor 守护程序
    ./ceph-mon --mkfs -i ${hostname} --monmap ${monmap_path}/monmap --keyring ${mon_keyring_path}/ceph.mon.keyring

    # 启动 monitor 服务
    touch ${mon_data_path}/ceph-${hostname} /done
    ./ceph-mon -i ${hostname}
    # ./ceph mon enable-msgr2
}

create_mon
