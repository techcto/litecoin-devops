#!/bin/bash

export $(egrep -v '^#' .env | xargs)
args=("$@")

export TAG_RELEASE=$(date +"%y.%m%d.%S")
export SOLODEV_RELEASE=$TAG_RELEASE
export AWS_PROFILE=develop
DATE=$(date +%d%H%M)

init(){
    git submodule init
    git submodule add -f https://github.com/litecoin-project/litecoin.git ./submodules/litecoin
}


bundle(){
    docker-compose -f docker-compose.bundle.yml up --build
}

ami(){
    cd devops/ami
    rm -Rf files/Litecoin.zip litecoin-manifest.json
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

cft(){
    export AWS_PROFILE=develop
    cd devops/cloudformation
    cp -f litecoin-pro-linux.yaml.dst litecoin-pro-linux.yaml
    AMI_LC=$(jq -r '.builds[0].artifact_id|split(":")[1]' ../ami/litecoin-manifest.json )
    sed -i "s/{CustomAMI}/$AMI_LC/g" litecoin-pro-linux.yaml
    sed -i "s/{SOLODEV_RELEASE}/$SOLODEV_RELEASE/g" litecoin-pro-linux.yaml
    aws s3 cp litecoin-pro-linux.yaml s3://litecoin-pro/cloudformation/litecoin-pro-linux.yaml --acl public-read

    LC=1
    if [ $LC == 1 ]; then
        echo "Create Litecoin Pro"
        aws cloudformation create-stack --disable-rollback --stack-name lc-tmp-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            --parameters file://params/litecoin-pro-linux.json \
            --template-url https://s3.amazonaws.com/litecoin-pro/cloudformation/litecoin-pro-linux.yaml
    fi
}

$*