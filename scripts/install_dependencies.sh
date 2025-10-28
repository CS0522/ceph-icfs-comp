#!/usr/bin/env bash

# Run this script on remote machine with root.

# set -x

function usage()
{
    echo "Usage: bash ./install_dependencies.sh"
}

##### params #####

# load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/basic_config

##### install dependencies #####

function install_by_yum()
{
    yum install -y vim git cmake gcc automake wget \
                python3 python3-devel python3-pip \
                libibverbs libibverbs-devel \
                systemd-udev systemd-devel \
                libblkid libblkid-devel \
                keyutils keyutils-libs-devel \
                openldap openldap-devel \
                cryptsetup cryptsetup-libs cryptsetup-devel \
                libaio libaio-devel \
                sqlite sqlite-devel \
                lz4 lz4-devel \
                curl curl-devel \
                gperftools gperftools-devel \
                jemalloc jemalloc-devel \
                openssl openssl-devel \
                expat expat-devel \
                liboath liboath-devel \
                libnl3 libnl3-devel \
                pkgconfig \
                liburing liburing-devel \
                libcap-ng-devel \
                thrift-devel \
                gperf \
                fuse-devel \
                re2 re2-devel \
                libbabeltrace libbabeltrace-devel \
                liboath liboath-devel \
                lttng-ust lttng-ust-devel \
                lmdb-devel \
                librdkafka librdkafka-devel \
                nasm \
                libcap-devel \
                numactl numactl-devel \
                lua lua-devel \
                snappy snappy-devel \
                python3-sphinx python3-Cython \
                python3-prettytable python3-pyyaml
}

function build_ninja()
{
    cd ${home_path}
    git clone ${ninja_repo}
    cd ninja
    python3 configure.py --bootstrap

    echo 'export PATH=$PATH:'"${home_path}"'/ninja' >> ~/.bashrc
    source ~/.bashrc
}

function install_rabbitmq()
{
    # import signs
    ## primary RabbitMQ signing key
    rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc'
    ## modern Erlang repository
    rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key'
    ## RabbitMQ server repository
    rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key'

    cp ${SCRIPT_DIR}/${rabbitmq_repo} /etc/yum.repos.d/

    dnf update -y && \
    dnf install -y logrotate erlang rabbitmq-server
    yum install -y librabbitmq librabbitmq-devel
}

function install_babeltrace_devel()
{
    yum update -y glibc && \
    yum install -y glib2 glib2-devel \
                elfutils elfutils-devel \
                libtool

    cd ${home_path}
    git clone -b v${babeltrace_version} ${babeltrace_repo}
    cd babeltrace
    ./bootstrap && ./configure
    make -j`nproc` && make install && ldconfig
}


install_by_yum
build_ninja
install_rabbitmq
install_babeltrace_devel
