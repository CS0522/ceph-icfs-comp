#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_create_monmap.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function create_monmap()
{
    cd ${ceph_bin_path}
    ./monmaptool --create --add ${hostnames[1]} ${local_ips[1]} --fsid ${fsid} ${monmap_path}/monmap
    ./monmaptool --add ${hostnames[2]} ${local_ips[2]} --fsid ${fsid} ${monmap_path}/monmap
    ./monmaptool --add ${hostnames[3]} ${local_ips[3]} --fsid ${fsid} ${monmap_path}/monmap
}

create_monmap
