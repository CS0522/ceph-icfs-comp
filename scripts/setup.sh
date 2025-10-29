#!/usr/bin/env bash

# Run this script on local machine.

# Steps:
# 1. 上传本地机器 PubKey 以支持 root 登录
# 2. 挂载 sda4
# 3. clone 仓库
# 4. 上传本地 basic_config 配置
# 5. 远程机器执行安装、编译，异步
# 6. 配置静态 IP

# set -x

function usage()
{
    echo "Usage: bash ./setup.sh"
}

##### args #####

log="setup.log"

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config


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
        scp ${scp_arg} ~/.ssh/id_rsa.pub ${username}@${hostname}:~/
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
            cd ~
            wget https://raw.githubusercontent.com/CS0522/rocksdb-rubbledb/rubble/rubble/setup-keys.sh
            sudo bash setup-keys.sh
ENDSSH
        ssh ${ssh_arg} ${username}@${hostname} << ENDSSH
            sudo bash -c "cat /users/${username}/id_rsa.pub >> /root/.ssh/authorized_keys"
ENDSSH
    done
}

# set hostname
function set_hostname()
{
    local len=${#hostnames[@]}
    for ((idx=0; idx<${len}; idx++)); do
        echo "Setting hostname: ${hostnames[idx]} as: node${idx}"
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            hostnamectl set-hostname node${idx}
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
        scp ${scp_arg} ${SCRIPT_DIR}/basic_config root@${hostname}:${proj_scripts_path}/basic_config
    done
}

# install dependencies
function install_dependencies()
{
    echo "***** Installing dependencies *****"
    # Rocky Linux 9
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} "cd ${proj_scripts_path}; rm -rf ${log}; bash ./install_dependencies.sh >> ${log} 2>&1" &
    done
    wait
}

# build ceph
function build_ceph()
{
    echo "***** Building ceph *****"
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} "cd ${proj_scripts_path}; bash ./build_ceph.sh >> ${log} 2>&1" &
    done
    wait
}

# configure IPs
function configure_ips()
{
    echo "***** Configuring ips *****"
    local len=${#hostnames[@]}
    for ((idx=0; idx<${len}; idx++)); do
        echo "Configuring hostname: ${hostnames[idx]}, ip: ${local_ips[idx]}"
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            cd ${proj_scripts_path}
            bash ./configure_ips.sh ${idx}
ENDSSH
    done
}

log="configure.log"

# configure ceph
function configure_ceph()
{
    echo "***** Configuring ceph *****"
    local len=${#hostnames[@]}
    # create directories
    for ((idx=1; idx<${len}; idx++)); do
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            mkdir -p ${ceph_conf_path}
            mkdir -p ${ceph_data_base_path}
            mkdir -p ${ceph_keyring_path}
            mkdir -p ${mon_data_path}
            mkdir -p ${mgr_data_path}
            mkdir -p ${osd_data_path}
ENDSSH
    done
    # setup 'ceph.conf'
    for ((idx=1; idx<${len}; idx++)); do
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            cd ${proj_scripts_path}
            bash ./configure_ceph_setup_conf.sh
ENDSSH
    done
    # create keyring on one node
    ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
        cd ${proj_scripts_path}
        bash ./configure_ceph_create_keyring.sh
ENDSSH
    # create monmap on one node
    ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
        cd ${proj_scripts_path}
        bash ./configure_ceph_create_monmap.sh
ENDSSH
    # synchronize keyring, monmap
    for ((idx=2; idx<${len}; idx++)); do
        local remote_hostname=${hostnames[idx]}
        ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
            cd ${proj_scripts_path}
            bash ./configure_ceph_sync_keyring_monmap.sh ${remote_hostname}
ENDSSH
    done
    # create monitor
    for ((idx=1; idx<${len}; idx++)); do
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            cd ${proj_scripts_path}
            bash ./configure_ceph_create_mon.sh
ENDSSH
    done
    # create manager on one node
    ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
        cd ${proj_scripts_path}
        bash ./configure_ceph_create_mgr.sh
ENDSSH
    # create osd
    for ((idx=1; idx<${len}; idx++)); do
        local osd_idx=$((idx - 1))
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            cd ${proj_scripts_path}
            bash ./configure_ceph_create_osd.sh ${osd_idx}
ENDSSH
    done

    # verify ceph status
    ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
        cd ${ceph_bin_path}
        ./ceph -s
ENDSSH
    sleep 5

}

function client_connect_rbd()
{

}


function setup_fn()
{
    setup_public_key
    set_hostname
    mount_sda4
    clone_proj_repo
    upload_config
    install_dependencies
    build_ceph
    configure_ips
    # FIXME: configure ceph 阶段的脚本还没功能测试，
    #        按照文档手动配置 ceph
    # configure_ceph
}

setup_fn
