#!/bin/bash

export $(egrep -v '^#' .env | xargs)
args=("$@")

export TAG_RELEASE=$(date +"%y.%m%d.%S")
export SOLODEV_RELEASE=$TAG_RELEASE
export AWS_PROFILE=develop

init(){
    git submodule init
    git submodule add -f https://github.com/litecoin-project/litecoin.git ./submodules/litecoin
}


bundle(){
    docker-compose -f docker-compose.bundle.yml up --build
}

ami(){
    cd devops/ami
    rm -Rf files/Litecoin.zip
    cp ../../dist/litecoin.zip files/Litecoin.zip
    ./build.sh config litecoin-packer.json
}

build(){
    DEBIAN_FRONTEND=noninteractive
    TZ=America/New_York

    apt update
    apt-get install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 libssl-dev libdb-dev libdb++-dev
    apt-get install -y libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev libfmt-dev
    #BerkleyDB for wallet support
    apt-get install -y libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools
    #upnp
    apt-get install -y libminiupnpc-dev
    #ZMQ
    apt-get install -y libzmq3-dev
    #build litecoin source
    ./autogen.sh
    ./configure --with-incompatible-bdb
    make
    make install
}

$*