#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_sync_keyring_monmap.sh <remote_hostname>"
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

remote_hostname=$1

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function sync_fn()
{
    scp ${scp_arg} ${client_admin_keyring_path}/ceph.client.admin.keyring root@${remote_hostname}:${client_admin_keyring_path}/

    scp ${scp_arg} ${mon_keyring_path}/ceph.mon.keyring root@${remote_hostname}:${mon_keyring_path}/

    scp ${scp_arg} ${monmap_path}/monmap root@${remote_hostname}:${monmap_path}

    scp ${scp_arg} ${ceph_keyring_path}/ceph.keyring root@${remote_hostname}:${ceph_keyring_path}/
}

sync_fn
