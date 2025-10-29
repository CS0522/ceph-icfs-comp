#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_create_keyring.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function create_keyring()
{
    cd ${ceph_bin_path}
    mkdir -p ${keyring_path}
    ./ceph-authtool --create-keyring ${mon_keyring_path}/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
    ./ceph-authtool --create-keyring ${client_admin_keyring_path}/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
    ./ceph-authtool --create-keyring ${keyring_path}/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'
    ./ceph-authtool ${mon_keyring_path}/ceph.mon.keyring --import-keyring ${client_admin_keyring_path}/ceph.client.admin.keyring
    ./ceph-authtool ${mon_keyring_path}/ceph.mon.keyring --import-keyring ${keyring_path}/ceph.keyring

    chown ceph:ceph ${mon_keyring_path}/ceph.mon.keyring
}

create_keyring
