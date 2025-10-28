#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x

function usage()
{
    echo "Usage: bash ./build_ceph.sh"
}

##### params #####

# load config
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/basic_config

##### build ceph #####

function build_ceph()
{
    cd ${home_path}
    wget ${ceph_download_base_path}/${ceph_archive}
    tar -zxf ${ceph_archive}
    
    cd ceph-${ceph_version} && rm -rf build
    ./do_cmake.sh
    cd build && ninja
}

build_ceph
