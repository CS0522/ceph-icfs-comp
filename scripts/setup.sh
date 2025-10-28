#!/usr/bin/env bash

# Run this script on local machine.

# Steps:
# 1. 上传本地机器 PubKey 以支持 root 登录
# 2. 挂载 sda4
# 3. clone 仓库
# 4. 上传本地 basic_config 配置
# 5. 远程机器执行安装、编译，异步
# 6. 

# set -x

function usage()
{
    echo "Usage: bash ./setup.sh"
}

##### args #####

log="setup.log"

##### params #####

# load config
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/basic_config

setup_sh_path="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"

echo "Username: ${username}"
echo "Client hostname: ${client}"
echo -n "Server hostnames: "
for s in ${servers[@]}; do
    echo -n "${s} "
done
echo ''

##### Setup #####

# Add public key to root in order to directly use root access
function setup_public_key()
{
    echo "***** Setting up public key *****"
    for hostname in ${hostnames[@]}; do
        scp ${scp_arg} ~/.ssh/id_rsa.pub ${username}@${hostname}:/home/${username}
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
            cd /home/${username}
            wget https://raw.githubusercontent.com/CS0522/rocksdb-rubbledb/rubble/rubble/setup-keys.sh
            sudo bash setup-keys.sh
ENDSSH
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
            cd /home/${username}
            sudo bash -c "cat ~/id_rsa.pub >> /root/.ssh/authorized_keys"
ENDSSH
    done
}

# for r650
function mount_sda4()
{
    echo "***** Mounting sda4 *****"
    # 注意没有写分区表，重启后会丢失，需要再次挂载
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    mkdir -p ${home_path}
            echo -e "n\np\n4\n\n\nw" | fdisk /dev/sda
            mkfs -F -t ${fs_type} /dev/sda4
            mount /dev/sda4 ${home_path}
            rm -rf ${home_path}/*
ENDSSH
    done
}

# clone project repo
function clone_proj_repo()
{
    echo "***** Cloning project repo *****"
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${home_path}
            rm -rf ${proj_name}
            git clone ${proj_repo}
ENDSSH
    done
}

# upload config
function upload_config()
{
    echo "***** Uploading config *****"
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
		    cd ${proj_scripts_path}
            rm -rf ./basic_config
ENDSSH
        # upload
        scp ${scp_arg} ${setup_sh_path}/basic_config root@${hostname}:${proj_scripts_path}/basic_config
    done
}

# install dependencies
function install_dependencies()
{
    echo "***** Installing dependencies *****"
    # Rocky Linux 9
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} "cd ${home_path}; rm -rf ${log}; bash ./install_dependencies.sh >> ${log} 2>&1" &
    done
    wait
}

# build ceph
function build_ceph()
{
    echo "***** Building ceph *****"
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} "cd ${home_path}; bash ./build_ceph.sh >> ${log} 2>&1" &
    done
    wait
}

function setup_fn()
{
    setup_public_key
    mount_sda4
    clone_proj_repo
    upload_config
    install_dependencies
    build_ceph
}

setup_fn
