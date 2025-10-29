#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x

# NOTE: This is a script containing several configuration steps, 
#       and will invoke other sub script tasks of each step.

# Steps:
# setup 'ceph.conf';
# create keyring;
# create monmap;
# synchronize keyring, monmap across all storage nodes;
# create monitor;
# 


function usage()
{
    echo "Usage: bash ./configure_ceph.sh <node_idx>"
    echo "node_idx:         the index of this node on CloudLab. e.g. '1' means node1, ip is: 10.10.1.2"
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

node_idx=$1

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function configure_ceph()
{
    cd ${proj_scripts_path}
    bash ./configure_ceph_setup_conf.sh
    mkdir -p 
    # create keyring only execute on one node
    cd ${proj_scripts_path}
    bash ./configure_ceph_create_keyring.sh
    # create monmap only execute on one node
    # synchronized keyring, monmap
}

configure_ceph
