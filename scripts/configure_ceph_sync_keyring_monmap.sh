#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_sync_keyring_monmap.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function sync_fn()
{
    scp ${client_admin_keyring_path}/ceph.client.admin.keyring root@${hostnames[2]}:${client_admin_keyring_path}/
    scp ${client_admin_keyring_path}/ceph.client.admin.keyring root@${hostnames[3]}:${client_admin_keyring_path}/

    scp ${mon_keyring_path}/ceph.mon.keyring root@${hostnames[2]}:${mon_keyring_path}/
    scp ${mon_keyring_path}/ceph.mon.keyring root@${hostnames[3]}:${mon_keyring_path}/

    scp ${monmap_path}/monmap root@${hostnames[2]}:${monmap_path}
    scp ${monmap_path}/monmap root@${hostnames[3]}:${monmap_path}
}

sync_fn
