#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x

function usage()
{
    echo "Usage: bash ./configure_ips.sh <local_ip>"
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

local_ip=$1
echo "local_ip: ${local_ip}"

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### configure ips #####

nic_port=""

function get_nic_port()
{
    nic_port=`ifconfig | awk '/^[[:alnum:]]+:/{interface=substr($1, 1, length($1)-1)} /mtu 9000/{print interface; exit}'`
    echo "nic_port: ${nic_port}"
}

function configure_ips()
{
    systemctl restart NetworkManager
    nmcli connection add type ethernet ifname ${nic_port} con-name ${nic_port} ipv4.addresses ${local_ip}/${netmask} ipv4.gateway 0.0.0.0 ipv4.method manual
}

get_nic_port
configure_ips
