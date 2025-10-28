#!/usr/bin/env bash

# Run this script on local machine.

# Steps:
# TODO

# set -x

function usage()
{
    echo "Usage: ./setup.sh <grpc_or_brpc> <nodes_num> <hostnames...>"
    echo "        <grpc_or_brpc>: '0' for grpc, '1' for brpc"
    echo "        <nodes_num>: nodes number (>=2), including client and servers"
    echo "        <hostnames...>: hostnames list, the first host is client, remains are servers"
    echo "        hostnames list only needs one hostname, like 'amd247.utah.cloudlab.us'"
}

# check args
if [ $# -lt 3 ]; then
    usage
    exit
fi

##### args #####

grpc_or_brpc=$1
nodes_num=$2
# if [ ${nodes_num} -lt 2 ]; then
#     usage
#     exit
# fi
shift 2
# all nodes' hostnames
hostnames=("$@")
# client hostname
client=$1
shift 1
# servers hostnames
servers=("$@")


##### params #####

# load configs
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/basic_config
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/nofdb_config

setup_sh_path="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"

echo "Username: ${username}"
echo "Client hostname: ${client}"
echo -n "Server hostnames: "
for s in ${servers[@]}; do
    echo -n "${s} "
done
echo ''

##### Setup #####

# install dependencies and touch hushlogin
function install_dependencies()
{
    # Ubuntu 20.04
    # touch .hushlogin file for no 'Welcome to Ubuntu'
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
		    sudo apt update
		    sudo apt install -y vim cmake make g++ build-essential \
                        autoconf libtool zip unzip git libtbb-dev \
                        libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev \
                        libboost-all-dev nvme-cli \
                        librdmacm-dev libibverbs-dev ibverbs-providers infiniband-diags 
		    touch /users/${username}/.hushlogin
            mkdir -p ${home_path}
            mkdir -p ${twitter_trace_path}
ENDSSH
    done
}

# NEW: Add public key to root in order to directly use root access
function setup_public_key()
{
    for hostname in ${hostnames[@]}; do
        scp ${scp_arg} ~/.ssh/id_rsa.pub ${username}@${hostname}:~/
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
            cd ${home_path}/../
            wget https://raw.githubusercontent.com/CS0522/rocksdb-rubbledb/rubble/rubble/setup-keys.sh
            sudo bash setup-keys.sh
ENDSSH
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
            sudo bash -c "cat ~/id_rsa.pub >> /root/.ssh/authorized_keys"
            sudo touch /root/.hushlogin
ENDSSH
    done
}

# for r650
function mount_sda4()
{
    # 注意没有写分区表，重启后会丢失，需要再次挂载
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    mkdir -p ${home_path}
            mkdir -p ${twitter_trace_path}
            mkfs -F -t ${fs_type} /dev/sda4
            mount /dev/sda4 ${home_path}
            rm -rf ${home_path}/*
            chown -R ${owner} ${home_path}
ENDSSH
    done
}

function mount_nvme()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${proj_scripts_path}
            bash ./mount_nvme.sh "nofdb"
		    exit
ENDSSH
    done
}

# clone private repos
function clone_nofdb_repo()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
		    cd ${home_path}
            sudo rm -rf nofdb
            git clone -b client-send-replica ${proj_repo}
ENDSSH
    done
}

# upload config
# upload local nofdb_config_default.h
function upload_config()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
		    cd ${proj_scripts_path}
            rm -rf ./basic_config
            cd ${nofdb_scripts_path}
            rm -rf ./nofdb_config
            cd ${proj_setup_path}/rocksdb/db/nofdb
            rm -rf ./nofdb_config_default.h
		    exit
ENDSSH
        # upload
        scp ${scp_arg} ${setup_sh_path}/basic_config ${username}@${hostname}:${proj_scripts_path}/basic_config
        scp ${scp_arg} ${setup_sh_path}/nofdb_config ${username}@${hostname}:${nofdb_scripts_path}/nofdb_config
        scp ${scp_arg} ${setup_sh_path}/../rocksdb/db/nofdb/nofdb_config_default.h ${username}@${hostname}:${proj_setup_path}/rocksdb/db/nofdb/nofdb_config_default.h
    done
}

function setup_grpc()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_grpc.sh
		    exit
ENDSSH
    done
}

function setup_brpc()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_brpc.sh
		    exit
ENDSSH
    done
}

function setup_spdk()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_spdk.sh
		    exit
ENDSSH
    done
}

# no use
function setup_isa_l()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_isa_l.sh
		    exit
ENDSSH
    done
}

function build_nofdb()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_nofdb.sh
		    exit
ENDSSH
    done
}

# build nofdb_server
function build_rpc_layer()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_rpc_layer.sh ${grpc_or_brpc}
		    exit
ENDSSH
    done
}

function setup_ycsbc()
{
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${nofdb_scripts_path}
            bash ./setup_ycsbc.sh ${grpc_or_brpc}
		    exit
ENDSSH
    done
}


function check_setup_result()
{
    echo ""
    echo ""
    echo "***** Checking setup result *****"

    for hostname in ${hostnames[@]}; do
        echo ""
        echo "***** Checking host: ${hostname}"
        local res=$(
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
		    cd ${home_path}
ENDSSH
        )
        echo ${res}
    done
    echo ""
    echo "***** Check done *****"
}

function setup_fn()
{
    install_dependencies
    setup_public_key
    mount_sda4
    clone_nofdb_repo
    upload_config
    setup_spdk
    # mount_nvme
    if [ "${grpc_or_brpc}" == "0" ]; then
        setup_grpc
    else
        setup_brpc
    fi
    build_nofdb
    build_rpc_layer
    setup_ycsbc

    check_setup_result
}

setup_fn
