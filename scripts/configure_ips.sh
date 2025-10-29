#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x

function usage()
{
    echo "Usage: bash ./configure_ips.sh <node_idx>"
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

##### configure ips #####

local_ip=${local_ips[node_idx]}
echo "local_ip: ${local_ip}"
nic_port=""

function get_nic_port()
{
    nic_port=`ifconfig | awk '/^[[:alnum:]]+:/{interface=substr($1, 1, length($1)-1)} /mtu 9000/{print interface; exit}'`
    echo "nic_port: ${nic_port}"
}

function configure_ips()
{
    systemctl restart NetworkManager
    sleep 3
    nmcli connection delete ${nic_port}
    nmcli connection add type ethernet ifname ${nic_port} con-name ${nic_port} ipv4.addresses ${local_ip}/${netmask} ipv4.gateway 0.0.0.0 ipv4.method manual
    nmcli connection down ${nic_port} && nmcli connection up ${nic_port}
}

get_nic_port
configure_ips
