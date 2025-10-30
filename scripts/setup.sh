#!/usr/bin/env bash

# Run this script on local machine.

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
        local new_hostname="node${idx}"
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            hostnamectl set-hostname ${new_hostname}
            echo "127.0.0.1 localhost ${new_hostname}" >> /etc/hosts
            sed -i.bak '1d' /etc/hosts
            cat /etc/hosts
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

function partition_nvme()
{
    echo "***** Partitioning nvme disk *****"
    local len=${#hostnames[@]}
    for ((idx=1; idx<${len}; idx++)); do
        ssh ${ssh_arg} root@${hostnames[idx]} << ENDSSH
            cd ${proj_scripts_path}
            bash partition_nvme.sh
ENDSSH
    done
}

# clone project repo
function clone_proj_repo()
{
    echo "***** Cloning project repo *****"
    for hostname in ${hostnames[@]}; do
        ssh ${ssh_arg} root@${hostname} << ENDSSH
            mkdir -p ${home_path}
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
    # client retrieve keyring, ceph.conf
    ssh ${ssh_arg} root@${hostnames[0]} << ENDSSH
        scp ${scp_arg} root@node1:${client_admin_keyring_path}/ceph.client.admin.keyring ${client_admin_keyring_path}/ceph.client.admin.keyring
        scp ${scp_arg} root@node1:${ceph_conf_path}/ceph.conf  ${ceph_conf_path}/ceph.conf 
ENDSSH

    # create rbdpool on ceph cluster
    ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
        cd ${ceph_bin_path}
        ./ceph osd pool create ${rbd_pool_name}
        ./rbd pool init ${rbd_pool_name}
        ./ceph df
ENDSSH

    # create rbd image
    ssh ${ssh_arg} root@${hostnames[1]} << ENDSSH
        cd ${ceph_bin_path}
        ./rbd create ${rbd_pool_name}/${rbd_image_name} --size=${rbd_image_size}
        ./rbd list -p ${rbd_pool_name}
        ./rbd info ${rbd_pool_name}/${rbd_image_name}
ENDSSH

    # client mount rbd device
    ssh ${ssh_arg} root@${hostnames[0]} << ENDSSH
        cd ${ceph_bin_path}
        ./rbd map ${rbd_pool_name}/${rbd_image_name}
        lsblk
ENDSSH

    # client mount rbd at mount point
    ssh ${ssh_arg} root@${hostnames[0]} << ENDSSH
        mkfs.xfs /dev/rbd0
        mkdir -p ${rbd_dev_mount_point}
        mount /dev/rbd0 ${rbd_dev_mount_point}
        lsblk
ENDSSH
}


function setup_fn()
{
    setup_public_key
    set_hostname
    mount_sda4
    partition_nvme
    clone_proj_repo
    upload_config
    install_dependencies
    build_ceph
    configure_ips
    configure_ceph
}

setup_fn
client_connect_rbd
