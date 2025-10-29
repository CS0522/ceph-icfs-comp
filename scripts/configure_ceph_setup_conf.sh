#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x


function usage()
{
    echo "Usage: bash ./configure_ceph_setup_conf.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ceph #####

function setup_conf()
{
    mkdir -p ${ceph_conf_path}
    cp ${SCRIPT_DIR}/ceph.conf ${ceph_conf_path}/
}

setup_conf
